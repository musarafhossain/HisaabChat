import db from '@adonisjs/lucid/services/db'
import { Exception } from '@adonisjs/core/exceptions'
import { errors as vineErrors } from '@vinejs/vine'
import type { TransactionClientContract } from '@adonisjs/lucid/types/database'
import { DateTime } from 'luxon'
import RecurringOccurrence from '#models/recurring_occurrence'
import RecurringRule, { type RecurringType } from '#models/recurring_rule'
import Transaction from '#models/transaction'
import type User from '#models/user'
import {
  datesBetween,
  nextAfter,
  nextOnOrAfter,
  type Frequency,
  type Schedule,
} from '#services/schedule'
import TransactionService from '#services/transaction_service'

export type RuleInput = {
  type: RecurringType
  amount: number
  accountId: string
  toAccountId?: string | null
  categoryId?: string | null
  note?: string | null
  frequency: Frequency
  interval?: number
  dayOfMonth?: number | null
  /** Local date of the first occurrence. */
  startDate: DateTime
  endDate?: DateTime | null
  /** true = add the transaction on the due date; false = remind and wait for Confirm. */
  autoCreate?: boolean
  /**
   * An existing transaction that is this rule's first occurrence (the form's
   * "Repeat" field): it gets linked instead of being created again.
   */
  linkTransactionId?: string | null
}

export type RuleChanges = Partial<Omit<RuleInput, 'linkTransactionId'>> & { isActive?: boolean }

export type ConfirmInput = {
  id?: string
  amount?: number
  accountId?: string
  categoryId?: string | null
  date?: DateTime
  note?: string | null
}

/** Never create more than this many past occurrences for one rule in one run. */
const MAX_CATCH_UP = 60

const notFound = (what = 'Recurring rule') =>
  new Exception(`${what} not found`, { status: 404, code: 'E_NOT_FOUND' })
const fieldError = (field: string, message: string, rule = 'invalid') =>
  new vineErrors.E_VALIDATION_ERROR([{ field, message, rule }])

/** Calendar date ("YYYY-MM-DD") of a DATE column value. */
const isoDate = (value: DateTime) => value.toUTC().toISODate()!
const dateValue = (iso: string) => DateTime.fromISO(iso, { zone: 'utc' })

const scheduleOf = (rule: RecurringRule): Schedule => ({
  frequency: rule.frequency,
  interval: rule.interval,
  dayOfMonth: rule.dayOfMonth,
  startDate: isoDate(rule.startDate),
  endDate: rule.endDate ? isoDate(rule.endDate) : null,
})

const todayFor = (user: User, now: DateTime = DateTime.utc()) =>
  now.setZone(user.timezone).toISODate()!

/** Midnight of a local date in the user's zone, as a UTC instant. */
const startOfLocalDay = (user: User, date: string) =>
  DateTime.fromISO(date, { zone: user.timezone }).startOf('day').toUTC()

export default class RecurringService {
  // ───────────────────────── rules ─────────────────────────

  static async list(user: User) {
    await this.process({ user })
    return RecurringRule.query()
      .where('userId', user.id)
      .preload('account')
      .preload('toAccount')
      .preload('category')
      .orderBy('isActive', 'desc')
      .orderBy('nextRunAt')
  }

  static async find(user: User, id: string) {
    const rule = await RecurringRule.query()
      .where('userId', user.id)
      .where('id', id)
      .preload('account')
      .preload('toAccount')
      .preload('category')
      .first()
    if (!rule) throw notFound()
    return rule
  }

  static async create(user: User, input: RuleInput) {
    const rule = await db.transaction(async (trx) => {
      await TransactionService.assertValid(trx, user, { ...input, date: DateTime.utc() })
      const startDate = isoDate(input.startDate)
      const schedule: Schedule = {
        frequency: input.frequency,
        interval: input.interval ?? 1,
        dayOfMonth:
          input.frequency === 'MONTHLY' ? (input.dayOfMonth ?? input.startDate.day) : null,
        startDate,
        endDate: input.endDate ? isoDate(input.endDate) : null,
      }
      if (schedule.endDate && schedule.endDate < startDate) {
        throw fieldError('endDate', 'The end date must be after the start date')
      }

      const linked = input.linkTransactionId
        ? await this.linkable(user, input.linkTransactionId, trx)
        : null
      // A linked transaction is the first occurrence; otherwise start today at the earliest.
      const firstDue = linked
        ? nextAfter(schedule, startDate)
        : nextOnOrAfter(schedule, startDate > todayFor(user) ? startDate : todayFor(user))

      const created = await RecurringRule.create(
        {
          userId: user.id,
          type: input.type,
          amount: input.amount,
          accountId: input.accountId,
          toAccountId: input.type === 'TRANSFER' ? (input.toAccountId ?? null) : null,
          categoryId: input.type === 'TRANSFER' ? null : (input.categoryId ?? null),
          note: input.note?.trim() || null,
          frequency: schedule.frequency,
          interval: schedule.interval,
          dayOfMonth: schedule.dayOfMonth ?? null,
          startDate: dateValue(startDate),
          endDate: schedule.endDate ? dateValue(schedule.endDate) : null,
          nextRunAt: firstDue ? startOfLocalDay(user, firstDue) : DateTime.utc(),
          autoCreate: input.autoCreate ?? false,
          isActive: firstDue !== null,
        },
        { client: trx }
      )

      if (linked) {
        linked.merge({ recurringRuleId: created.id, occurrenceDate: dateValue(startDate) })
        await linked.useTransaction(trx).save()
        await RecurringOccurrence.create(
          {
            recurringRuleId: created.id,
            dueDate: dateValue(startDate),
            status: 'CONFIRMED',
            transactionId: linked.id,
          },
          { client: trx }
        )
      }
      return created
    })

    await this.process({ user, ruleId: rule.id })
    return this.find(user, rule.id)
  }

  /**
   * Changes the template or the schedule. A new schedule restarts from today
   * (dates that already have an occurrence are never repeated).
   */
  static async update(user: User, id: string, changes: RuleChanges) {
    const rule = await this.find(user, id)
    const merged = {
      type: changes.type ?? rule.type,
      amount: changes.amount ?? rule.amount,
      accountId: changes.accountId ?? rule.accountId,
      toAccountId: changes.toAccountId !== undefined ? changes.toAccountId : rule.toAccountId,
      categoryId: changes.categoryId !== undefined ? changes.categoryId : rule.categoryId,
    }

    await db.transaction(async (trx) => {
      await TransactionService.assertValid(trx, user, { ...merged, date: DateTime.utc() })
      rule.merge({
        ...merged,
        toAccountId: merged.type === 'TRANSFER' ? merged.toAccountId : null,
        categoryId: merged.type === 'TRANSFER' ? null : merged.categoryId,
        note: changes.note !== undefined ? changes.note?.trim() || null : rule.note,
        autoCreate: changes.autoCreate ?? rule.autoCreate,
        frequency: changes.frequency ?? rule.frequency,
        interval: changes.interval ?? rule.interval,
        dayOfMonth: changes.dayOfMonth !== undefined ? changes.dayOfMonth : rule.dayOfMonth,
        startDate: changes.startDate ?? rule.startDate,
        endDate: changes.endDate !== undefined ? changes.endDate : rule.endDate,
        isActive: changes.isActive ?? rule.isActive,
      })
      if (rule.frequency !== 'MONTHLY') rule.dayOfMonth = null
      else rule.dayOfMonth ??= rule.startDate.toUTC().day

      const schedule = scheduleOf(rule)
      if (schedule.endDate && schedule.endDate < schedule.startDate) {
        throw fieldError('endDate', 'The end date must be after the start date')
      }
      const next = await this.nextFree(rule, todayFor(user), trx)
      rule.nextRunAt = next ? startOfLocalDay(user, next) : rule.nextRunAt
      if (!next) rule.isActive = false
      await rule.useTransaction(trx).save()
    })

    await this.process({ user, ruleId: rule.id })
    return this.find(user, id)
  }

  /** Deletes the rule; transactions it already added stay. */
  static async delete(user: User, id: string) {
    const rule = await this.find(user, id)
    await rule.delete()
  }

  // ───────────────────────── occurrences ─────────────────────────

  /**
   * Makes every due occurrence exist: auto-add rules get their transaction,
   * remind-me rules get a PENDING occurrence. Safe to run any number of times
   * (unique keys on rule + date). Runs for one user on reads, and for
   * everyone from `node ace recurring:run`.
   */
  static async process(options: { user?: User; ruleId?: string; now?: DateTime } = {}) {
    const now = options.now ?? DateTime.utc()
    const query = RecurringRule.query()
      .where('isActive', true)
      .where('nextRunAt', '<=', now.toJSDate())
      .preload('user')
    if (options.user) query.where('userId', options.user.id)
    if (options.ruleId) query.where('id', options.ruleId)

    let created = 0
    for (const rule of await query) {
      created += await this.catchUp(rule, rule.user, now)
    }
    return created
  }

  /**
   * "Due soon" for Home: occurrences waiting for Confirm/Skip, dates coming up
   * in the next [days] days, and money people are due to give back.
   */
  static async upcoming(user: User, days = 7) {
    await this.process({ user })
    const today = todayFor(user)
    const until = DateTime.fromISO(today).plus({ days }).toISODate()!

    const pending = await RecurringOccurrence.query()
      .where('status', 'PENDING')
      .whereHas('rule', (q) => q.where('userId', user.id))
      .preload('rule', (q) => q.preload('account').preload('toAccount').preload('category'))
      .orderBy('dueDate')
      .orderBy('createdAt')

    const rules = await RecurringRule.query()
      .where('userId', user.id)
      .where('isActive', true)
      .preload('account')
      .preload('toAccount')
      .preload('category')
    const upcoming = rules
      .flatMap((rule) => {
        const from = DateTime.fromJSDate(rule.nextRunAt.toJSDate()).setZone(user.timezone)
        const start = from.toISODate()! > today ? from.toISODate()! : today
        return datesBetween(scheduleOf(rule), start, until, 10).map((date) => ({ rule, date }))
      })
      .filter((item) => item.date > today || !item.rule.autoCreate)
      .sort((a, b) => a.date.localeCompare(b.date))

    // Due dates where that person's balance still points the same way
    // (they still owe you for a LEND, you still owe them for a BORROW).
    const dues = await db.rawQuery(
      `SELECT * FROM (
         SELECT t.id AS transactionId, t.type AS type, t.due_date AS dueDate, t.amount AS amount,
                p.id AS personId, p.name AS personName, p.color AS personColor,
                (SELECT COALESCE(SUM(CASE x.type WHEN 'LEND' THEN x.amount WHEN 'REPAY' THEN x.amount
                                     WHEN 'BORROW' THEN -x.amount WHEN 'COLLECT' THEN -x.amount END), 0)
                 FROM transactions x WHERE x.person_id = p.id)
                  * (CASE t.type WHEN 'LEND' THEN 1 ELSE -1 END) AS outstanding
         FROM transactions t
         JOIN people p ON p.id = t.person_id
         WHERE t.user_id = ? AND t.type IN ('LEND', 'BORROW') AND t.due_date IS NOT NULL
           AND t.due_date <= ? AND p.archived_at IS NULL
       ) d
       WHERE d.outstanding > 0
       ORDER BY d.dueDate`,
      [user.id, until]
    )
    const dueRows = dues[0] as Array<{
      transactionId: string
      type: 'LEND' | 'BORROW'
      dueDate: Date | string
      amount: number
      outstanding: number
      personId: string
      personName: string
      personColor: string
    }>

    return {
      today,
      pending,
      upcoming,
      dues: dueRows.map((row) => ({
        transactionId: row.transactionId,
        type: row.type,
        dueDate:
          typeof row.dueDate === 'string'
            ? row.dueDate.slice(0, 10)
            : DateTime.fromJSDate(row.dueDate, { zone: 'utc' }).toISODate()!,
        // What's still owed, if less than this entry (part was paid back).
        amount: Math.min(Number(row.amount), Number(row.outstanding)),
        person: { id: row.personId, name: row.personName, color: row.personColor },
      })),
    }
  }

  /**
   * Turns a PENDING occurrence into a transaction (the user may adjust the
   * amount, account, category, date or note first).
   */
  static async confirm(user: User, occurrenceId: string, input: ConfirmInput) {
    const transactionId = await db.transaction(async (trx) => {
      const occurrence = await this.lockPending(user, occurrenceId, trx)
      const rule = await RecurringRule.findOrFail(occurrence.recurringRuleId, { client: trx })
      const dueDate = isoDate(occurrence.dueDate)
      const transaction = await TransactionService.createWithin(
        trx,
        user,
        {
          id: input.id,
          type: rule.type,
          amount: input.amount ?? rule.amount,
          accountId: input.accountId ?? rule.accountId,
          toAccountId: rule.toAccountId,
          categoryId: input.categoryId !== undefined ? input.categoryId : rule.categoryId,
          date: input.date ?? this.entryTime(user, dueDate, DateTime.utc()),
          note: input.note !== undefined ? input.note : rule.note,
        },
        { recurringRuleId: rule.id, occurrenceDate: dateValue(dueDate) }
      )
      occurrence.merge({ status: 'CONFIRMED', transactionId: transaction.id })
      await occurrence.useTransaction(trx).save()
      return transaction.id
    })
    return TransactionService.load(transactionId)
  }

  static async skip(user: User, occurrenceId: string) {
    await db.transaction(async (trx) => {
      const occurrence = await this.lockPending(user, occurrenceId, trx)
      occurrence.status = 'SKIPPED'
      await occurrence.useTransaction(trx).save()
    })
  }

  // ───────────────────────── helpers ─────────────────────────

  /** Creates the occurrences from next_run_at up to today, then moves next_run_at on. */
  private static async catchUp(rule: RecurringRule, user: User, now: DateTime) {
    const today = todayFor(user, now)
    const schedule = scheduleOf(rule)
    const from = rule.nextRunAt.setZone(user.timezone).toISODate()!
    const due = datesBetween(schedule, from, today, MAX_CATCH_UP)

    let created = 0
    for (const date of due) {
      created += await this.occur(rule, user, date, now)
    }

    const last = due.at(-1) ?? today
    const next = nextAfter(schedule, last > today ? last : today)
    if (next) {
      rule.nextRunAt = startOfLocalDay(user, next)
    } else {
      rule.isActive = false
    }
    await rule.save()
    return created
  }

  /**
   * One due date: an auto-added transaction, or a PENDING occurrence. If the
   * transaction can't be added (say the account was archived) it waits for
   * the user as PENDING instead.
   */
  private static async occur(rule: RecurringRule, user: User, date: string, now: DateTime) {
    try {
      return await db.transaction(async (trx) => {
        const occurrence = await RecurringOccurrence.create(
          { recurringRuleId: rule.id, dueDate: dateValue(date), status: 'PENDING' },
          { client: trx }
        )
        if (!rule.autoCreate) return 1
        try {
          await TransactionService.assertValid(trx, user, this.template(rule, date, user, now))
        } catch {
          return 1 // stays PENDING
        }
        const transaction = await TransactionService.createWithin(
          trx,
          user,
          this.template(rule, date, user, now),
          { recurringRuleId: rule.id, occurrenceDate: dateValue(date) }
        )
        occurrence.merge({ status: 'CONFIRMED', transactionId: transaction.id })
        await occurrence.useTransaction(trx).save()
        return 1
      })
    } catch (error) {
      // Already handled by an earlier or concurrent run.
      if ((error as { code?: string }).code === 'ER_DUP_ENTRY') return 0
      throw error
    }
  }

  private static template(rule: RecurringRule, date: string, user: User, now: DateTime) {
    return {
      type: rule.type,
      amount: rule.amount,
      accountId: rule.accountId,
      toAccountId: rule.toAccountId,
      categoryId: rule.categoryId,
      note: rule.note,
      date: this.entryTime(user, date, now),
    }
  }

  /** 9:00 local on the due date, but never in the future. */
  private static entryTime(user: User, date: string, now: DateTime) {
    const nine = DateTime.fromISO(date, { zone: user.timezone }).set({ hour: 9 }).toUTC()
    return (nine > now ? now : nine).startOf('second')
  }

  /** First scheduled date on or after [from] that has no occurrence yet. */
  private static async nextFree(rule: RecurringRule, from: string, trx: TransactionClientContract) {
    const schedule = scheduleOf(rule)
    let date = nextOnOrAfter(schedule, from)
    while (date) {
      const taken = await RecurringOccurrence.query({ client: trx })
        .where('recurringRuleId', rule.id)
        .where('dueDate', date)
        .first()
      if (!taken) return date
      date = nextAfter(schedule, date)
    }
    return null
  }

  private static async linkable(user: User, id: string, trx: TransactionClientContract) {
    const transaction = await Transaction.query({ client: trx })
      .where('userId', user.id)
      .where('id', id)
      .forUpdate()
      .first()
    if (!transaction) throw fieldError('linkTransactionId', 'Transaction not found', 'exists')
    if (transaction.recurringRuleId) {
      throw fieldError('linkTransactionId', 'This transaction already repeats')
    }
    return transaction
  }

  private static async lockPending(user: User, id: string, trx: TransactionClientContract) {
    const occurrence = await RecurringOccurrence.query({ client: trx })
      .where('id', id)
      .whereHas('rule', (q) => q.where('userId', user.id))
      .forUpdate()
      .first()
    if (!occurrence) throw notFound('Occurrence')
    if (occurrence.status !== 'PENDING') {
      throw new Exception('This one was already confirmed or skipped', {
        status: 409,
        code: 'E_ALREADY_HANDLED',
      })
    }
    return occurrence
  }
}

import db from '@adonisjs/lucid/services/db'
import { Exception } from '@adonisjs/core/exceptions'
import { errors as vineErrors } from '@vinejs/vine'
import type { TransactionClientContract } from '@adonisjs/lucid/types/database'
import type { ModelQueryBuilderContract } from '@adonisjs/lucid/types/model'
import { DateTime } from 'luxon'
import Account from '#models/account'
import Category from '#models/category'
import Transaction, { type TransactionType } from '#models/transaction'
import type User from '#models/user'
import { applyEffects, effectsOf, negate } from '#services/balance_service'

type EditableType = Exclude<TransactionType, 'ADJUSTMENT'>

export type TransactionInput = {
  id?: string
  type: EditableType
  amount: number
  accountId: string
  toAccountId?: string | null
  categoryId?: string | null
  date: DateTime
  note?: string | null
}

export type TransactionChanges = Partial<Omit<TransactionInput, 'id'>>

export type TransactionFilters = {
  from?: DateTime
  to?: DateTime
  type?: TransactionType
  accountId?: string
  categoryId?: string
  q?: string
  cursor?: string
  limit?: number
}

const fieldError = (field: string, message: string, rule = 'invalid') =>
  new vineErrors.E_VALIDATION_ERROR([{ field, message, rule }])

const notFound = () => new Exception('Transaction not found', { status: 404, code: 'E_NOT_FOUND' })

const RELATIONS = ['account', 'toAccount', 'category'] as const

export default class TransactionService {
  /**
   * Creates an income, expense or transfer and moves balances in the same DB
   * transaction. Idempotent: posting an id that already exists returns it.
   */
  static async create(user: User, input: TransactionInput) {
    if (input.id) {
      const existing = await Transaction.find(input.id)
      if (existing) return { transaction: await this.owned(user, existing), created: false }
    }

    try {
      const transaction = await db.transaction(async (trx) => {
        const shape = this.normalize(input)
        await this.assertReferences(user, shape, trx, { checkArchived: true })
        const created = await Transaction.create({ ...shape, userId: user.id }, { client: trx })
        await applyEffects(trx, effectsOf(created))
        return created
      })
      return { transaction: await this.load(transaction.id), created: true }
    } catch (error) {
      // Two identical retries raced: the second insert hits the primary key.
      if (input.id && (error as { code?: string }).code === 'ER_DUP_ENTRY') {
        const existing = await Transaction.findOrFail(input.id)
        return { transaction: await this.owned(user, existing), created: false }
      }
      throw error
    }
  }

  /**
   * Edits any field, including type and account: the old balance effects are
   * reversed and the new ones applied, with the row locked.
   */
  static async update(user: User, id: string, changes: TransactionChanges) {
    await db.transaction(async (trx) => {
      const transaction = await this.lock(user, id, trx)
      if (transaction.type === 'ADJUSTMENT') {
        throw fieldError(
          'type',
          'Balance adjustments can’t be edited. Delete it and reconcile again.'
        )
      }

      const next = this.normalize({
        type: changes.type ?? (transaction.type as EditableType),
        amount: changes.amount ?? transaction.amount,
        accountId: changes.accountId ?? transaction.accountId,
        toAccountId:
          changes.toAccountId !== undefined ? changes.toAccountId : transaction.toAccountId,
        categoryId: changes.categoryId !== undefined ? changes.categoryId : transaction.categoryId,
        date: changes.date ?? transaction.date,
        note: changes.note !== undefined ? changes.note : transaction.note,
      })
      // Old entries on archived accounts stay editable; moving money onto an
      // archived account is not allowed.
      await this.assertReferences(user, next, trx, {
        checkArchived:
          next.accountId !== transaction.accountId || next.toAccountId !== transaction.toAccountId,
      })

      await applyEffects(trx, negate(effectsOf(transaction)))
      transaction.merge(next)
      await transaction.useTransaction(trx).save()
      await applyEffects(trx, effectsOf(transaction))
    })
    return this.load(id)
  }

  static async delete(user: User, id: string) {
    await db.transaction(async (trx) => {
      const transaction = await this.lock(user, id, trx)
      await applyEffects(trx, negate(effectsOf(transaction)))
      await transaction.useTransaction(trx).delete()
    })
  }

  /**
   * Records the difference between the app's balance and the real one as an
   * ADJUSTMENT entry. Returns null when they already match.
   */
  static async reconcile(user: User, accountId: string, actualBalance: number) {
    const id = await db.transaction(async (trx) => {
      const account = await Account.query({ client: trx })
        .where('userId', user.id)
        .where('id', accountId)
        .forUpdate()
        .first()
      if (!account) throw new Exception('Account not found', { status: 404, code: 'E_NOT_FOUND' })

      const difference = actualBalance - account.balance
      if (difference === 0) return null

      const adjustment = await Transaction.create(
        {
          userId: user.id,
          type: 'ADJUSTMENT',
          amount: Math.abs(difference),
          adjustmentDirection: difference > 0 ? 'INCREASE' : 'DECREASE',
          accountId: account.id,
          date: DateTime.utc().startOf('second'),
          note: 'Balance adjusted',
        },
        { client: trx }
      )
      await applyEffects(trx, effectsOf(adjustment))
      return adjustment.id
    })
    return id ? this.load(id) : null
  }

  static async find(user: User, id: string) {
    const transaction = await Transaction.query()
      .where('userId', user.id)
      .where('id', id)
      .preload('account')
      .preload('toAccount')
      .preload('category')
      .first()
    if (!transaction) throw notFound()
    return transaction
  }

  /**
   * Newest first, keyset-paginated on (date, id), plus income/expense totals
   * for the whole filtered set (not just the page).
   */
  static async list(user: User, filters: TransactionFilters) {
    const limit = filters.limit ?? 30
    const filtered = () =>
      this.applyFilters(Transaction.query().where('transactions.user_id', user.id), user, filters)

    const page = filtered()
      .preload('account')
      .preload('toAccount')
      .preload('category')
      .orderBy('date', 'desc')
      .orderBy('id', 'desc')
      .limit(limit + 1)

    const cursor = this.decodeCursor(filters.cursor)
    if (cursor) {
      page.where((query) =>
        query
          .where('date', '<', cursor.date.toJSDate())
          .orWhere((same) => same.where('date', cursor.date.toJSDate()).where('id', '<', cursor.id))
      )
    }

    const rows = await page
    const items = rows.slice(0, limit)
    const last = items.at(-1)
    const nextCursor = rows.length > limit && last ? this.encodeCursor(last) : null

    const totalsRow = await filtered()
      .sum({ income: db.raw("CASE WHEN type = 'INCOME' THEN amount ELSE 0 END") })
      .sum({ expense: db.raw("CASE WHEN type = 'EXPENSE' THEN amount ELSE 0 END") })
      .count('* as count')
      .first()
    const totals = {
      income: Number(totalsRow?.$extras.income ?? 0),
      expense: Number(totalsRow?.$extras.expense ?? 0),
      count: Number(totalsRow?.$extras.count ?? 0),
    }

    return { items, nextCursor, totals }
  }

  /**
   * The newest transaction touching each account (as source or destination),
   * for the WhatsApp-style "last message" preview in the accounts list.
   */
  static async latestPerAccount(userId: string) {
    const result = await db.rawQuery(
      `
      SELECT x.account_id AS accountId, x.txn_id AS txnId FROM (
        SELECT u.account_id, u.txn_id,
               ROW_NUMBER() OVER (PARTITION BY u.account_id ORDER BY u.date DESC, u.txn_id DESC) AS rn
        FROM (
          SELECT account_id, id AS txn_id, date FROM transactions WHERE user_id = ?
          UNION ALL
          SELECT to_account_id, id, date FROM transactions WHERE user_id = ? AND to_account_id IS NOT NULL
        ) u
      ) x
      WHERE x.rn = 1
      `,
      [userId, userId]
    )
    const pairs = result[0] as Array<{ accountId: string; txnId: string }>
    if (pairs.length === 0) return new Map<string, Transaction>()

    const transactions = await Transaction.query()
      .whereIn(
        'id',
        pairs.map((pair) => pair.txnId)
      )
      .preload('account')
      .preload('toAccount')
      .preload('category')
    const byId = new Map(transactions.map((t) => [t.id, t]))
    return new Map(pairs.map((pair) => [pair.accountId, byId.get(pair.txnId)!]))
  }

  // ───────────────────────── helpers ─────────────────────────

  private static applyFilters(
    query: ModelQueryBuilderContract<typeof Transaction, Transaction>,
    user: User,
    filters: TransactionFilters
  ) {
    if (filters.from) query.where('date', '>=', filters.from.toJSDate())
    if (filters.to) query.where('date', '<', filters.to.toJSDate())
    if (filters.type) query.where('type', filters.type)
    if (filters.categoryId) query.where('categoryId', filters.categoryId)
    if (filters.accountId) {
      const accountId = filters.accountId
      query.where((q) => q.where('accountId', accountId).orWhere('toAccountId', accountId))
    }
    if (filters.q) {
      const like = `%${filters.q.replace(/[\\%_]/g, (c) => `\\${c}`)}%`
      query.where((q) =>
        q
          .whereILike('note', like)
          .orWhereIn(
            'categoryId',
            db.from('categories').select('id').where('user_id', user.id).whereILike('name', like)
          )
      )
    }
    return query
  }

  /** Clears fields that don't belong to the type (see chk_txn_shape). */
  private static normalize<T extends Omit<TransactionInput, 'id'>>(input: T) {
    const isTransfer = input.type === 'TRANSFER'
    return {
      type: input.type,
      amount: input.amount,
      accountId: input.accountId,
      toAccountId: isTransfer ? (input.toAccountId ?? null) : null,
      categoryId: isTransfer ? null : (input.categoryId ?? null),
      date: input.date,
      note: input.note?.trim() ? input.note.trim() : null,
      ...('id' in input && input.id ? { id: input.id as string } : {}),
    }
  }

  private static async assertReferences(
    user: User,
    shape: ReturnType<typeof TransactionService.normalize>,
    trx: TransactionClientContract,
    options: { checkArchived: boolean }
  ) {
    const account = await Account.query({ client: trx })
      .where('userId', user.id)
      .where('id', shape.accountId)
      .first()
    if (!account) throw fieldError('accountId', 'Choose one of your accounts', 'exists')
    if (options.checkArchived && account.archived) {
      throw fieldError(
        'accountId',
        `${account.name} is archived. Unarchive it to add transactions.`
      )
    }

    if (shape.type === 'TRANSFER') {
      if (!shape.toAccountId)
        throw fieldError('toAccountId', 'Choose the account to transfer to', 'required')
      if (shape.toAccountId === shape.accountId) {
        throw fieldError('toAccountId', 'Choose two different accounts')
      }
      const target = await Account.query({ client: trx })
        .where('userId', user.id)
        .where('id', shape.toAccountId)
        .first()
      if (!target) throw fieldError('toAccountId', 'Choose one of your accounts', 'exists')
      if (options.checkArchived && target.archived) {
        throw fieldError(
          'toAccountId',
          `${target.name} is archived. Unarchive it to add transactions.`
        )
      }
      return
    }

    if (!shape.categoryId) throw fieldError('categoryId', 'Choose a category', 'required')
    const category = await Category.query({ client: trx })
      .where('userId', user.id)
      .where('id', shape.categoryId)
      .first()
    if (!category) throw fieldError('categoryId', 'Choose one of your categories', 'exists')
    if (category.type !== shape.type) {
      throw fieldError(
        'categoryId',
        shape.type === 'INCOME' ? 'Choose an income category' : 'Choose an expense category'
      )
    }
  }

  private static async lock(user: User, id: string, trx: TransactionClientContract) {
    const transaction = await Transaction.query({ client: trx })
      .where('userId', user.id)
      .where('id', id)
      .forUpdate()
      .first()
    if (!transaction) throw notFound()
    return transaction
  }

  private static async owned(user: User, transaction: Transaction) {
    if (transaction.userId !== user.id) {
      throw new Exception('This id is already in use', { status: 409, code: 'E_ID_CONFLICT' })
    }
    return this.load(transaction.id)
  }

  private static load(id: string) {
    return Transaction.query()
      .where('id', id)
      .preload(RELATIONS[0])
      .preload(RELATIONS[1])
      .preload(RELATIONS[2])
      .firstOrFail()
  }

  private static encodeCursor(transaction: Transaction) {
    return Buffer.from(JSON.stringify({ d: transaction.date.toISO(), i: transaction.id })).toString(
      'base64url'
    )
  }

  private static decodeCursor(cursor?: string) {
    if (!cursor) return null
    try {
      const { d, i } = JSON.parse(Buffer.from(cursor, 'base64url').toString('utf8'))
      const date = DateTime.fromISO(d, { zone: 'utc' })
      if (!date.isValid || typeof i !== 'string') throw new Error('bad cursor')
      return { date, id: i }
    } catch {
      throw fieldError('cursor', 'Invalid cursor')
    }
  }
}

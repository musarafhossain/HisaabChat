import { DateTime } from 'luxon'
import db from '@adonisjs/lucid/services/db'
import type User from '#models/user'
import Account from '#models/account'
import Budget from '#models/budget'
import Category from '#models/category'
import Person from '#models/person'
import RecurringRule from '#models/recurring_rule'
import Transaction from '#models/transaction'
import { toDecimalString } from '#services/money'

export type CsvFilters = {
  /** First local day to include (YYYY-MM-DD, user's time zone) */
  from?: string
  /** Last local day to include (YYYY-MM-DD) */
  to?: string
  accountId?: string
  personId?: string
}

const TYPE_LABELS: Record<string, string> = {
  EXPENSE: 'Expense',
  INCOME: 'Income',
  TRANSFER: 'Transfer',
  ADJUSTMENT: 'Adjustment',
  LEND: 'Lent',
  BORROW: 'Borrowed',
  COLLECT: 'Got back',
  REPAY: 'Paid back',
}

const CSV_HEADER = [
  'Date',
  'Time',
  'Type',
  'Amount',
  'Signed amount',
  'Account',
  'To account',
  'Category',
  'Person',
  'Note',
  'Due date',
  'Recurring',
  'Id',
]

/**
 * One CSV cell. Quotes when needed, and defuses text that a spreadsheet
 * would run as a formula (=, +, -, @ at the start).
 */
function cell(value: string | number | null | undefined, { text = true } = {}) {
  if (value === null || value === undefined) return ''
  let out = String(value)
  if (text && /^[=+\-@\t\r]/.test(out)) out = `'${out}`
  return /[",\r\n]/.test(out) ? `"${out.replaceAll('"', '""')}"` : out
}

/**
 * Money in (+) or out (−) of the account it's on. Transfers and the people
 * types follow BalanceService: LEND/REPAY leave the account, BORROW/COLLECT
 * arrive. A transfer is 0 overall (it only moves money between accounts).
 */
function signed(type: string, amount: number, direction: string | null) {
  switch (type) {
    case 'INCOME':
    case 'BORROW':
    case 'COLLECT':
      return amount
    case 'EXPENSE':
    case 'LEND':
    case 'REPAY':
      return -amount
    case 'ADJUSTMENT':
      return direction === 'DECREASE' ? -amount : amount
    default:
      return 0
  }
}

const isoDate = (value: DateTime | null) => (value ? value.toISODate() : null)

/** Downloads: CSV of transactions, and everything as JSON (docs/02-TRD.md §4). */
export default class ExportService {
  /** A file name like `hisaabchat-transactions-2026-10-01-to-2026-10-31.csv`. */
  static csvFileName(filters: CsvFilters) {
    const range =
      filters.from && filters.to
        ? `${filters.from}-to-${filters.to}`
        : filters.from
          ? `from-${filters.from}`
          : filters.to
            ? `to-${filters.to}`
            : 'all'
    return `hisaabchat-transactions-${range}.csv`
  }

  /**
   * Transactions, oldest first, with names instead of ids. Dates are in the
   * user's time zone; amounts are plain rupees ("1250.50") so spreadsheets
   * can add them up. Starts with a BOM so Excel reads ₹ and names as UTF-8.
   */
  static async transactionsCsv(user: User, filters: CsvFilters = {}) {
    const zone = user.timezone
    const query = db
      .from('transactions as t')
      .join('accounts as a', 'a.id', 't.account_id')
      .leftJoin('accounts as ta', 'ta.id', 't.to_account_id')
      .leftJoin('categories as c', 'c.id', 't.category_id')
      .leftJoin('categories as pc', 'pc.id', 'c.parent_id')
      .leftJoin('people as p', 'p.id', 't.person_id')
      .where('t.user_id', user.id)
      .select(
        't.id',
        't.type',
        't.amount',
        't.date',
        't.note',
        't.adjustment_direction',
        't.due_date',
        't.recurring_rule_id',
        'a.name as account',
        'ta.name as to_account',
        'c.name as category',
        'pc.name as parent_category',
        'p.name as person'
      )
      .orderBy('t.date', 'asc')
      .orderBy('t.id', 'asc')

    if (filters.from) {
      const start = DateTime.fromISO(filters.from, { zone }).startOf('day')
      query.where('t.date', '>=', start.toUTC().toJSDate())
    }
    if (filters.to) {
      const end = DateTime.fromISO(filters.to, { zone }).startOf('day').plus({ days: 1 })
      query.where('t.date', '<', end.toUTC().toJSDate())
    }
    if (filters.accountId) {
      const accountId = filters.accountId
      query.where((q) => q.where('t.account_id', accountId).orWhere('t.to_account_id', accountId))
    }
    if (filters.personId) query.where('t.person_id', filters.personId)

    const rows = await query
    const lines = [CSV_HEADER.join(',')]
    for (const row of rows) {
      const when = DateTime.fromJSDate(row.date, { zone: 'utc' }).setZone(zone)
      const category = row.parent_category
        ? `${row.parent_category} / ${row.category}`
        : row.category
      const due = row.due_date
        ? DateTime.fromJSDate(row.due_date, { zone: 'utc' }).toISODate()
        : null
      lines.push(
        [
          cell(when.toISODate(), { text: false }),
          cell(when.toFormat('HH:mm'), { text: false }),
          cell(TYPE_LABELS[row.type] ?? row.type),
          cell(toDecimalString(row.amount), { text: false }),
          cell(toDecimalString(signed(row.type, row.amount, row.adjustment_direction)), {
            text: false,
          }),
          cell(row.account),
          cell(row.to_account),
          cell(category),
          cell(row.person),
          cell(row.note),
          cell(due, { text: false }),
          cell(row.recurring_rule_id ? 'Yes' : ''),
          cell(row.id, { text: false }),
        ].join(',')
      )
    }
    return '﻿' + lines.join('\r\n') + '\r\n'
  }

  /** A file name like `hisaabchat-backup-2026-10-11.json` (user's local date). */
  static jsonFileName(user: User) {
    return `hisaabchat-backup-${DateTime.now().setZone(user.timezone).toISODate()}.json`
  }

  /**
   * Everything the user owns, ids included, amounts in paise (as in the API).
   * Meant as a personal backup and for moving to another app.
   */
  static async all(user: User) {
    const [accounts, categories, budgets, people, transactions, rules] = await Promise.all([
      Account.query().where('userId', user.id).orderBy('sortOrder').orderBy('createdAt'),
      Category.query().where('userId', user.id).orderBy('type').orderBy('sortOrder'),
      Budget.query().where('userId', user.id).preload('overrides').orderBy('sortOrder'),
      Person.query().where('userId', user.id).orderBy('createdAt'),
      Transaction.query().where('userId', user.id).orderBy('date').orderBy('id'),
      RecurringRule.query().where('userId', user.id).orderBy('createdAt'),
    ])
    const utc = (value: DateTime | null) => (value ? value.toUTC().toISO() : null)

    return {
      app: 'HisaabChat',
      format: 1,
      exportedAt: DateTime.utc().toISO(),
      amountsIn: 'paise',
      user: {
        email: user.email,
        fullName: user.fullName,
        currency: user.currency,
        timezone: user.timezone,
        monthStartDay: user.monthStartDay,
        theme: user.theme,
        accentColor: user.accentColor,
        createdAt: utc(user.createdAt),
      },
      accounts: accounts.map((a) => ({
        id: a.id,
        name: a.name,
        type: a.type,
        openingBalance: a.openingBalance,
        balance: a.balance,
        creditLimit: a.creditLimit,
        includeInTotal: Boolean(a.includeInTotal),
        color: a.color,
        icon: a.icon,
        archivedAt: utc(a.archivedAt),
        createdAt: utc(a.createdAt),
      })),
      categories: categories.map((c) => ({
        id: c.id,
        name: c.name,
        type: c.type,
        parentId: c.parentId,
        budgetId: c.budgetId,
        color: c.color,
        icon: c.icon,
        isDefault: Boolean(c.isDefault),
        archivedAt: utc(c.archivedAt),
      })),
      budgets: budgets.map((b) => ({
        id: b.id,
        name: b.name,
        amount: b.amount,
        kind: b.kind,
        period: b.period,
        alertPercent: b.alertPercent,
        rollover: Boolean(b.rollover),
        startDate: isoDate(b.startDate),
        color: b.color,
        icon: b.icon,
        archivedAt: utc(b.archivedAt),
        overrides: b.overrides.map((o) => ({
          periodStart: isoDate(o.periodStart),
          amount: o.amount,
        })),
      })),
      people: people.map((p) => ({
        id: p.id,
        name: p.name,
        phone: p.phone,
        note: p.note,
        color: p.color,
        archivedAt: utc(p.archivedAt),
        createdAt: utc(p.createdAt),
      })),
      transactions: transactions.map((t) => ({
        id: t.id,
        type: t.type,
        amount: t.amount,
        date: utc(t.date),
        accountId: t.accountId,
        toAccountId: t.toAccountId,
        categoryId: t.categoryId,
        personId: t.personId,
        note: t.note,
        adjustmentDirection: t.adjustmentDirection,
        dueDate: isoDate(t.dueDate),
        recurringRuleId: t.recurringRuleId,
        createdAt: utc(t.createdAt),
      })),
      recurringRules: rules.map((r) => ({
        id: r.id,
        type: r.type,
        amount: r.amount,
        accountId: r.accountId,
        toAccountId: r.toAccountId,
        categoryId: r.categoryId,
        note: r.note,
        frequency: r.frequency,
        interval: r.interval,
        dayOfMonth: r.dayOfMonth,
        startDate: isoDate(r.startDate),
        endDate: isoDate(r.endDate),
        autoCreate: Boolean(r.autoCreate),
        isActive: Boolean(r.isActive),
      })),
    }
  }
}

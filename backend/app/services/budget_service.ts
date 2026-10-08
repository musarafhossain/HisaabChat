import db from '@adonisjs/lucid/services/db'
import { Exception } from '@adonisjs/core/exceptions'
import { errors as vineErrors } from '@vinejs/vine'
import { DateTime } from 'luxon'
import Budget, { type BudgetKind } from '#models/budget'
import BudgetPeriodOverride from '#models/budget_period_override'
import Category from '#models/category'
import Transaction from '#models/transaction'
import type User from '#models/user'
import {
  daysLeft,
  periodContaining,
  periodForMonth,
  shiftPeriod,
  type Period,
  type PeriodSettings,
} from '#services/period_service'

export type BudgetStatusCode = 'OK' | 'WARNING' | 'EXCEEDED'

export type BudgetInput = {
  name: string
  amount: number
  kind?: BudgetKind
  alertPercent?: number
  color?: string
  icon?: string
  categoryIds: string[]
}

export type BudgetChanges = Partial<BudgetInput> & { sortOrder?: number }

const notFound = () => new Exception('Budget not found', { status: 404, code: 'E_NOT_FOUND' })
const fieldError = (field: string, message: string, rule = 'invalid') =>
  new vineErrors.E_VALIDATION_ERROR([{ field, message, rule }])

const settingsOf = (user: User): PeriodSettings => ({
  timezone: user.timezone,
  monthStartDay: user.monthStartDay,
})

export default class BudgetService {
  // ───────────────────────── reads ─────────────────────────

  /**
   * Every active budget's status for one period (default: the current one),
   * plus totals and spending that isn't covered by any budget.
   */
  static async overview(user: User, month?: string) {
    const settings = settingsOf(user)
    const period = this.period(user, month)
    const budgets = await this.activeBudgets(user, period)
    const overrides = await this.overridesFor(
      budgets.map((b) => b.id),
      period
    )
    const spent = await this.spentByBudget(user.id, period)

    const statuses = budgets.map((budget) =>
      this.status(budget, overrides.get(budget.id), spent.get(budget.id) ?? 0, period, settings)
    )
    const budgeted = statuses.reduce((sum, s) => sum + s.budgeted, 0)
    const spentInBudgets = statuses.reduce((sum, s) => sum + s.spent, 0)

    return {
      month: period.month,
      periodStart: period.periodStart,
      periodEnd: period.periodEnd,
      daysLeft: daysLeft(period, settings),
      budgets: statuses,
      totals: { budgeted, spent: spentInBudgets, remaining: budgeted - spentInBudgets },
      unbudgeted: spent.get(null) ?? 0,
    }
  }

  /**
   * One budget for a period: status, the expenses counted toward it and the
   * last six periods of budget vs. spent.
   */
  static async detail(user: User, id: string, month?: string) {
    const settings = settingsOf(user)
    const period = this.period(user, month)
    const budget = await this.find(user, id)
    const categoryIds = await this.categoryIdsCounting(user.id, budget.id)

    const overrides = await this.overridesFor([budget.id], period)
    const spent = await this.spentFor(user.id, categoryIds, period)
    const status = this.status(budget, overrides.get(budget.id), spent, period, settings)

    const transactions = categoryIds.length
      ? await Transaction.query()
          .where('userId', user.id)
          .where('type', 'EXPENSE')
          .whereIn('categoryId', categoryIds)
          .where('date', '>=', period.start.toJSDate())
          .where('date', '<', period.end.toJSDate())
          .preload('account')
          .preload('toAccount')
          .preload('category')
          .orderBy('date', 'desc')
          .orderBy('id', 'desc')
      : []

    const history = []
    for (let i = 5; i >= 0; i--) {
      const past = shiftPeriod(period, -i, settings)
      const pastOverrides = await this.overridesFor([budget.id], past)
      const active = budget.startDate.toISODate()! <= past.periodEnd
      history.push({
        month: past.month,
        budgeted: active ? (pastOverrides.get(budget.id) ?? budget.amount) : null,
        spent: await this.spentFor(user.id, categoryIds, past),
      })
    }

    return {
      ...status,
      transactions,
      history,
      periodStart: period.periodStart,
      periodEnd: period.periodEnd,
    }
  }

  /**
   * Alerts for an expense that was just created: a budget crossing its alert
   * level or its limit because of this transaction.
   */
  static async alertsForNewExpense(user: User, transaction: Transaction) {
    if (transaction.type !== 'EXPENSE' || !transaction.categoryId) return []
    const rows = await db.rawQuery(
      `SELECT COALESCE(c.budget_id, p.budget_id) AS budgetId
       FROM categories c LEFT JOIN categories p ON p.id = c.parent_id
       WHERE c.id = ? AND c.user_id = ?`,
      [transaction.categoryId, user.id]
    )
    const budgetId = (rows[0] as Array<{ budgetId: string | null }>)[0]?.budgetId
    if (!budgetId) return []

    const budget = await Budget.query().where('id', budgetId).whereNull('archivedAt').first()
    if (!budget) return []

    const settings = settingsOf(user)
    const period = periodContaining(settings, transaction.date)
    const categoryIds = await this.categoryIdsCounting(user.id, budget.id)
    const after = await this.spentFor(user.id, categoryIds, period)
    const before = after - transaction.amount
    const overrides = await this.overridesFor([budget.id], period)
    const budgeted = overrides.get(budget.id) ?? budget.amount
    if (budgeted <= 0) return []

    const percentBefore = (before * 100) / budgeted
    const percentAfter = (after * 100) / budgeted
    const crossedLimit = before <= budgeted && after > budgeted
    const crossedAlert = percentBefore < budget.alertPercent && percentAfter >= budget.alertPercent
    if (!crossedLimit && !crossedAlert) return []

    return [
      {
        budgetId: budget.id,
        name: budget.name,
        percent: Math.round(percentAfter),
        status: (crossedLimit ? 'EXCEEDED' : 'WARNING') as BudgetStatusCode,
        remaining: budgeted - after,
      },
    ]
  }

  // ───────────────────────── writes ─────────────────────────

  static async create(user: User, input: BudgetInput) {
    await this.assertNameAvailable(user, input.name)
    const period = periodContaining(settingsOf(user))

    return db.transaction(async (trx) => {
      const categories = await this.assertCategories(user, input.categoryIds)
      const first = categories[0]
      const max = await Budget.query({ client: trx })
        .where('userId', user.id)
        .max('sort_order as max')
        .first()
      const sortMax = max?.$extras.max as number | null | undefined

      const budget = await Budget.create(
        {
          userId: user.id,
          name: input.name,
          amount: input.amount,
          kind: input.kind ?? 'VARIABLE',
          alertPercent: input.alertPercent ?? 80,
          color: input.color ?? first.color,
          icon: input.icon ?? first.icon,
          startDate: DateTime.fromISO(period.periodStart),
          sortOrder: sortMax === null || sortMax === undefined ? 0 : sortMax + 1,
          rollover: false,
          period: 'MONTHLY',
        },
        { client: trx }
      )
      await trx
        .from('categories')
        .where('user_id', user.id)
        .whereIn('id', input.categoryIds)
        .update({ budget_id: budget.id })
      return budget
    })
  }

  static async update(user: User, id: string, changes: BudgetChanges) {
    const budget = await this.find(user, id)
    if (changes.name !== undefined) await this.assertNameAvailable(user, changes.name, id)
    if (changes.categoryIds) await this.assertCategories(user, changes.categoryIds, id)

    await db.transaction(async (trx) => {
      const { categoryIds, ...fields } = changes
      budget.merge(fields)
      await budget.useTransaction(trx).save()

      if (categoryIds) {
        await trx
          .from('categories')
          .where('user_id', user.id)
          .where('budget_id', id)
          .whereNotIn('id', categoryIds)
          .update({ budget_id: null })
        await trx
          .from('categories')
          .where('user_id', user.id)
          .whereIn('id', categoryIds)
          .update({ budget_id: id })
      }
    })
    return budget
  }

  /**
   * Archiving frees the categories so they can join another budget.
   */
  static async archive(user: User, id: string) {
    const budget = await this.find(user, id)
    await db.transaction(async (trx) => {
      const now = DateTime.utc().startOf('second')
      // Names are unique per user (DB index), so free the name for reuse.
      const suffix = ` · archived ${now.toFormat('yyyy-MM-dd HH:mm')}`
      budget.name = budget.name.slice(0, 60 - suffix.length) + suffix
      budget.archivedAt = now
      await budget.useTransaction(trx).save()
      await trx.from('categories').where('budget_id', id).update({ budget_id: null })
    })
    return budget
  }

  /** A different amount for one period only ("Education ₹15,000 in fees month"). */
  static async setOverride(user: User, id: string, month: string, amount: number) {
    const budget = await this.find(user, id)
    const period = periodForMonth(month, settingsOf(user))
    await BudgetPeriodOverride.updateOrCreate(
      { budgetId: budget.id, periodStart: DateTime.fromISO(period.periodStart) },
      { amount }
    )
  }

  static async deleteOverride(user: User, id: string, month: string) {
    const budget = await this.find(user, id)
    const period = periodForMonth(month, settingsOf(user))
    await BudgetPeriodOverride.query()
      .where('budgetId', budget.id)
      .where('periodStart', period.periodStart)
      .delete()
  }

  static async find(user: User, id: string) {
    const budget = await Budget.query()
      .where('userId', user.id)
      .where('id', id)
      .whereNull('archivedAt')
      .preload('categories', (q) => q.orderBy('sortOrder'))
      .first()
    if (!budget) throw notFound()
    return budget
  }

  // ───────────────────────── helpers ─────────────────────────

  private static period(user: User, month?: string): Period {
    const settings = settingsOf(user)
    return month ? periodForMonth(month, settings) : periodContaining(settings)
  }

  private static activeBudgets(user: User, period: Period) {
    return Budget.query()
      .where('userId', user.id)
      .whereNull('archivedAt')
      .where('startDate', '<=', period.periodEnd)
      .preload('categories', (q) => q.orderBy('sortOrder'))
      .orderBy('sortOrder')
      .orderBy('createdAt')
  }

  private static status(
    budget: Budget,
    override: number | undefined,
    spent: number,
    period: Period,
    settings: PeriodSettings
  ) {
    const budgeted = override ?? budget.amount
    const remaining = budgeted - spent
    const percent = budgeted > 0 ? Math.round((spent * 100) / budgeted) : spent > 0 ? 100 : 0
    const status: BudgetStatusCode =
      spent > budgeted ? 'EXCEEDED' : percent >= budget.alertPercent ? 'WARNING' : 'OK'
    const left = daysLeft(period, settings)

    return {
      id: budget.id,
      name: budget.name,
      kind: budget.kind,
      color: budget.color,
      icon: budget.icon,
      alertPercent: budget.alertPercent,
      categories: budget.categories.map((c) => ({
        id: c.id,
        name: c.name,
        icon: c.icon,
        color: c.color,
      })),
      amount: budget.amount,
      budgeted,
      hasOverride: override !== undefined,
      rolloverIn: 0,
      spent,
      remaining,
      percent,
      status,
      daysLeft: left,
      safeToSpendPerDay:
        budget.kind === 'VARIABLE' && left > 0 ? Math.floor(Math.max(remaining, 0) / left) : null,
    }
  }

  /**
   * Spent per budget in a period (key null = expenses in no budget).
   * A sub-category counts toward its own budget, else its parent's.
   */
  private static async spentByBudget(userId: string, period: Period) {
    const result = await db.rawQuery(
      `SELECT COALESCE(c.budget_id, p.budget_id) AS budgetId, SUM(t.amount) AS spent
       FROM transactions t
       JOIN categories c ON c.id = t.category_id
       LEFT JOIN categories p ON p.id = c.parent_id
       WHERE t.user_id = ? AND t.type = 'EXPENSE' AND t.date >= ? AND t.date < ?
       GROUP BY COALESCE(c.budget_id, p.budget_id)`,
      [userId, period.start.toJSDate(), period.end.toJSDate()]
    )
    const rows = result[0] as Array<{ budgetId: string | null; spent: number }>
    return new Map(rows.map((row) => [row.budgetId, Number(row.spent)]))
  }

  /** Category ids whose expenses count toward [budgetId]. */
  private static async categoryIdsCounting(userId: string, budgetId: string) {
    const result = await db.rawQuery(
      `SELECT c.id FROM categories c LEFT JOIN categories p ON p.id = c.parent_id
       WHERE c.user_id = ? AND COALESCE(c.budget_id, p.budget_id) = ?`,
      [userId, budgetId]
    )
    return (result[0] as Array<{ id: string }>).map((row) => row.id)
  }

  private static async spentFor(userId: string, categoryIds: string[], period: Period) {
    if (categoryIds.length === 0) return 0
    const row = await db
      .from('transactions')
      .where('user_id', userId)
      .where('type', 'EXPENSE')
      .whereIn('category_id', categoryIds)
      .where('date', '>=', period.start.toJSDate())
      .where('date', '<', period.end.toJSDate())
      .sum('amount as spent')
      .first()
    return Number(row?.spent ?? 0)
  }

  private static async overridesFor(budgetIds: string[], period: Period) {
    if (budgetIds.length === 0) return new Map<string, number>()
    const rows = await BudgetPeriodOverride.query()
      .whereIn('budgetId', budgetIds)
      .where('periodStart', period.periodStart)
    return new Map(rows.map((row) => [row.budgetId, row.amount]))
  }

  /**
   * Categories must be the user's own expense categories and not already in
   * another budget (each expense counts toward at most one budget).
   */
  private static async assertCategories(user: User, ids: string[], budgetId?: string) {
    const unique = [...new Set(ids)]
    const categories = await Category.query()
      .where('userId', user.id)
      .whereIn('id', unique)
      .preload('budget')
      .orderBy('sortOrder')
    if (categories.length !== unique.length) {
      throw fieldError('categoryIds', 'Choose from your own categories', 'exists')
    }
    if (categories.some((c) => c.type !== 'EXPENSE')) {
      throw fieldError('categoryIds', 'Budgets track expense categories only')
    }
    const taken = categories.find((c) => c.budgetId && c.budgetId !== budgetId)
    if (taken) {
      throw fieldError(
        'categoryIds',
        `${taken.name} is already in the “${taken.budget?.name ?? 'other'}” budget`,
        'unique'
      )
    }
    return categories
  }

  private static async assertNameAvailable(user: User, name: string, exceptId?: string) {
    const query = Budget.query()
      .where('userId', user.id)
      .where('name', name)
      .whereNull('archivedAt')
    if (exceptId) query.whereNot('id', exceptId)
    if (await query.first())
      throw fieldError('name', 'You already have a budget with this name', 'unique')
  }
}

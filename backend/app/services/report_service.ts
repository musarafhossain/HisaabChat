import db from '@adonisjs/lucid/services/db'
import Transaction from '#models/transaction'
import type User from '#models/user'
import AccountService from '#services/account_service'
import BudgetService from '#services/budget_service'
import {
  periodContaining,
  periodForMonth,
  shiftPeriod,
  type Period,
  type PeriodSettings,
} from '#services/period_service'

const settingsOf = (user: User): PeriodSettings => ({
  timezone: user.timezone,
  monthStartDay: user.monthStartDay,
})

export default class ReportService {
  /**
   * Home dashboard: net worth, this period's money in/out, budgets and the
   * latest transactions.
   */
  static async dashboard(user: User, month?: string) {
    const period = this.period(user, month)
    const { accounts, netWorth } = await AccountService.list(user)
    const totals = await this.totals(user.id, period)
    const budgets = await BudgetService.overview(user, period.month)
    const recent = await Transaction.query()
      .where('userId', user.id)
      .preload('account')
      .preload('toAccount')
      .preload('category')
      .preload('person')
      .orderBy('date', 'desc')
      .orderBy('id', 'desc')
      .limit(8)

    return {
      month: period.month,
      periodStart: period.periodStart,
      periodEnd: period.periodEnd,
      netWorth,
      accountsCount: accounts.length,
      income: totals.income,
      expense: totals.expense,
      net: totals.income - totals.expense,
      budgets: budgets.budgets,
      budgetTotals: budgets.totals,
      recent,
    }
  }

  /**
   * Spending (or income) per category for a period, largest first.
   * Sub-categories are reported under their own name.
   */
  static async byCategory(user: User, type: 'EXPENSE' | 'INCOME', month?: string) {
    const period = this.period(user, month)
    const result = await db.rawQuery(
      `SELECT c.id AS categoryId, c.name AS name, c.icon AS icon, c.color AS color,
              SUM(t.amount) AS total, COUNT(*) AS count
       FROM transactions t
       JOIN categories c ON c.id = t.category_id
       WHERE t.user_id = ? AND t.type = ? AND t.date >= ? AND t.date < ?
       GROUP BY c.id, c.name, c.icon, c.color
       ORDER BY total DESC, c.name ASC`,
      [user.id, type, period.start.toJSDate(), period.end.toJSDate()]
    )
    const rows = result[0] as Array<{
      categoryId: string
      name: string
      icon: string
      color: string
      total: number
      count: number
    }>
    const total = rows.reduce((sum, row) => sum + Number(row.total), 0)

    return {
      month: period.month,
      periodStart: period.periodStart,
      periodEnd: period.periodEnd,
      /** UTC bounds, for listing the transactions behind a row. */
      from: period.start.toUTC().toISO(),
      to: period.end.toUTC().toISO(),
      type,
      total,
      items: rows.map((row) => ({
        categoryId: row.categoryId,
        name: row.name,
        icon: row.icon,
        color: row.color,
        total: Number(row.total),
        count: Number(row.count),
        percent: total > 0 ? Math.round((Number(row.total) * 1000) / total) / 10 : 0,
      })),
    }
  }

  /**
   * Income, expense and net for the last [months] periods (oldest first),
   * ending with the given or current period.
   */
  static async trend(user: User, months: number, month?: string) {
    const settings = settingsOf(user)
    const last = this.period(user, month)
    const points = []
    for (let i = months - 1; i >= 0; i--) {
      const period = shiftPeriod(last, -i, settings)
      const totals = await this.totals(user.id, period)
      points.push({
        month: period.month,
        periodStart: period.periodStart,
        income: totals.income,
        expense: totals.expense,
        net: totals.income - totals.expense,
      })
    }
    return points
  }

  private static period(user: User, month?: string): Period {
    const settings = settingsOf(user)
    return month ? periodForMonth(month, settings) : periodContaining(settings)
  }

  /** Income and expense in a period (transfers and adjustments excluded). */
  private static async totals(userId: string, period: Period) {
    const row = await db
      .from('transactions')
      .where('user_id', userId)
      .where('date', '>=', period.start.toJSDate())
      .where('date', '<', period.end.toJSDate())
      .sum({ income: db.raw("CASE WHEN type = 'INCOME' THEN amount ELSE 0 END") })
      .sum({ expense: db.raw("CASE WHEN type = 'EXPENSE' THEN amount ELSE 0 END") })
      .first()
    return { income: Number(row?.income ?? 0), expense: Number(row?.expense ?? 0) }
  }
}

import type { HttpContext } from '@adonisjs/core/http'
import BudgetService from '#services/budget_service'
import {
  budgetHistoryValidator,
  createBudgetValidator,
  monthQueryValidator,
  overrideParamsValidator,
  overrideValidator,
  updateBudgetValidator,
} from '#validators/budget'

export default class BudgetsController {
  /**
   * GET /budgets?month=YYYY-MM → statuses for the period + totals + unbudgeted.
   */
  async index({ auth, request }: HttpContext) {
    const { month } = await request.validateUsing(monthQueryValidator, { data: request.qs() })
    return { data: await BudgetService.overview(auth.getUserOrFail(), month) }
  }

  /**
   * GET /budgets/history?months=6&month=YYYY-MM: totals per month, oldest first.
   */
  async history({ auth, request }: HttpContext) {
    const { month, months } = await request.validateUsing(budgetHistoryValidator, {
      data: request.qs(),
    })
    return { data: await BudgetService.history(auth.getUserOrFail(), months ?? 6, month) }
  }

  async show({ auth, params, request }: HttpContext) {
    const { month } = await request.validateUsing(monthQueryValidator, { data: request.qs() })
    return { data: await BudgetService.detail(auth.getUserOrFail(), params.id, month) }
  }

  async store({ auth, request, response }: HttpContext) {
    const user = auth.getUserOrFail()
    const input = await request.validateUsing(createBudgetValidator)
    const budget = await BudgetService.create(user, input)
    response.status(201)
    return { data: await BudgetService.detail(user, budget.id) }
  }

  async update({ auth, params, request }: HttpContext) {
    const user = auth.getUserOrFail()
    const changes = await request.validateUsing(updateBudgetValidator)
    await BudgetService.update(user, params.id, changes)
    return { data: await BudgetService.detail(user, params.id) }
  }

  async archive({ auth, params, response }: HttpContext) {
    await BudgetService.archive(auth.getUserOrFail(), params.id)
    return response.noContent()
  }

  /** PUT /budgets/:id/overrides/:month { amount } */
  async setOverride({ auth, params, request, response }: HttpContext) {
    const { amount, params: route } = await request.validateUsing(overrideValidator, {
      data: { ...request.body(), params },
    })
    await BudgetService.setOverride(auth.getUserOrFail(), params.id, route.month, amount)
    return response.noContent()
  }

  async deleteOverride({ auth, params, request, response }: HttpContext) {
    const { params: route } = await request.validateUsing(overrideParamsValidator, {
      data: { params },
    })
    await BudgetService.deleteOverride(auth.getUserOrFail(), params.id, route.month)
    return response.noContent()
  }
}

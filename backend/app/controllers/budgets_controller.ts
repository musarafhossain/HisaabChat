import type { HttpContext } from '@adonisjs/core/http'
import BudgetService from '#services/budget_service'
import TransactionTransformer from '#transformers/transaction_transformer'
import {
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

  async show({ auth, params, request, serialize }: HttpContext) {
    const { month } = await request.validateUsing(monthQueryValidator, { data: request.qs() })
    const { transactions, ...detail } = await BudgetService.detail(
      auth.getUserOrFail(),
      params.id,
      month
    )
    const items = await serialize.withoutWrapping(TransactionTransformer.transform(transactions))
    return { data: { ...detail, transactions: items } }
  }

  async store({ auth, request, response }: HttpContext) {
    const user = auth.getUserOrFail()
    const input = await request.validateUsing(createBudgetValidator)
    const budget = await BudgetService.create(user, input)
    response.status(201)
    return { data: await BudgetService.detail(user, budget.id).then(({ transactions, ...d }) => d) }
  }

  async update({ auth, params, request }: HttpContext) {
    const user = auth.getUserOrFail()
    const changes = await request.validateUsing(updateBudgetValidator)
    await BudgetService.update(user, params.id, changes)
    return { data: await BudgetService.detail(user, params.id).then(({ transactions, ...d }) => d) }
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

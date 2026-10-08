import type { HttpContext } from '@adonisjs/core/http'
import BudgetService from '#services/budget_service'
import TransactionService from '#services/transaction_service'
import TransactionTransformer from '#transformers/transaction_transformer'
import {
  createTransactionValidator,
  listTransactionsValidator,
  updateTransactionValidator,
} from '#validators/transaction'

export default class TransactionsController {
  /**
   * GET /transactions?from&to&type&accountId&categoryId&q&cursor&limit
   * → { data, meta: { nextCursor, totals: { income, expense, count } } }
   */
  async index({ auth, request, serialize }: HttpContext) {
    const filters = await request.validateUsing(listTransactionsValidator, { data: request.qs() })
    const { items, nextCursor, totals } = await TransactionService.list(
      auth.getUserOrFail(),
      filters
    )
    const data = await serialize.withoutWrapping(TransactionTransformer.transform(items))
    return { data, meta: { nextCursor, totals } }
  }

  /**
   * 201 when created; 200 with the existing record when the client retried
   * with the same id.
   */
  async store({ auth, request, response, serialize }: HttpContext) {
    const user = auth.getUserOrFail()
    const input = await request.validateUsing(createTransactionValidator)
    const { transaction, created } = await TransactionService.create(user, input)
    response.status(created ? 201 : 200)
    const data = await serialize.withoutWrapping(TransactionTransformer.transform(transaction))
    // Budgets this expense pushed past their alert level or limit.
    const budgetAlerts = created ? await BudgetService.alertsForNewExpense(user, transaction) : []
    return { data, budgetAlerts }
  }

  async show({ auth, params, serialize }: HttpContext) {
    const transaction = await TransactionService.find(auth.getUserOrFail(), params.id)
    return serialize(TransactionTransformer.transform(transaction))
  }

  async update({ auth, params, request, serialize }: HttpContext) {
    const changes = await request.validateUsing(updateTransactionValidator)
    const transaction = await TransactionService.update(auth.getUserOrFail(), params.id, changes)
    return serialize(TransactionTransformer.transform(transaction))
  }

  async destroy({ auth, params, response }: HttpContext) {
    await TransactionService.delete(auth.getUserOrFail(), params.id)
    return response.noContent()
  }
}

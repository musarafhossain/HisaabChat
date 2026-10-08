import type { HttpContext } from '@adonisjs/core/http'
import AccountService from '#services/account_service'
import TransactionService from '#services/transaction_service'
import AccountTransformer from '#transformers/account_transformer'
import TransactionTransformer, {
  lastTransactionPreview,
} from '#transformers/transaction_transformer'
import {
  createAccountValidator,
  listAccountsValidator,
  updateAccountValidator,
} from '#validators/account'
import { reconcileValidator } from '#validators/transaction'

export default class AccountsController {
  /**
   * GET /accounts?includeArchived=true
   * → { data: Account[] (each with lastTransaction), meta: { netWorth } }
   */
  async index({ auth, request, serialize }: HttpContext) {
    const user = auth.getUserOrFail()
    const { includeArchived } = await request.validateUsing(listAccountsValidator, {
      data: request.qs(),
    })
    const { accounts, netWorth } = await AccountService.list(user, { includeArchived })
    const latest = await TransactionService.latestPerAccount(user.id)

    const serialized = (await serialize.withoutWrapping(
      AccountTransformer.transform(accounts)
    )) as Array<{ id: string }>
    const data = serialized.map((account) => {
      const last = latest.get(account.id)
      return { ...account, lastTransaction: last ? lastTransactionPreview(account.id, last) : null }
    })
    return { data, meta: { netWorth } }
  }

  async store({ auth, request, response, serialize }: HttpContext) {
    const input = await request.validateUsing(createAccountValidator)
    const account = await AccountService.create(auth.getUserOrFail(), input)
    response.status(201)
    return serialize(AccountTransformer.transform(account))
  }

  async show({ auth, params, serialize }: HttpContext) {
    const account = await AccountService.find(auth.getUserOrFail(), params.id)
    return serialize(AccountTransformer.transform(account))
  }

  async update({ auth, params, request, serialize }: HttpContext) {
    const changes = await request.validateUsing(updateAccountValidator)
    const account = await AccountService.update(auth.getUserOrFail(), params.id, changes)
    return serialize(AccountTransformer.transform(account))
  }

  async archive({ auth, params, serialize }: HttpContext) {
    const account = await AccountService.setArchived(auth.getUserOrFail(), params.id, true)
    return serialize(AccountTransformer.transform(account))
  }

  async unarchive({ auth, params, serialize }: HttpContext) {
    const account = await AccountService.setArchived(auth.getUserOrFail(), params.id, false)
    return serialize(AccountTransformer.transform(account))
  }

  /**
   * POST /accounts/:id/reconcile { actualBalance } → the ADJUSTMENT created,
   * or { data: null } when the balance already matched.
   */
  async reconcile({ auth, params, request, serialize }: HttpContext) {
    const { actualBalance } = await request.validateUsing(reconcileValidator)
    const adjustment = await TransactionService.reconcile(
      auth.getUserOrFail(),
      params.id,
      actualBalance
    )
    if (!adjustment) return { data: null }
    return serialize(TransactionTransformer.transform(adjustment))
  }

  async destroy({ auth, params, response }: HttpContext) {
    await AccountService.delete(auth.getUserOrFail(), params.id)
    return response.noContent()
  }
}

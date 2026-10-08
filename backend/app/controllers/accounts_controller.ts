import type { HttpContext } from '@adonisjs/core/http'
import AccountService from '#services/account_service'
import AccountTransformer from '#transformers/account_transformer'
import {
  createAccountValidator,
  listAccountsValidator,
  updateAccountValidator,
} from '#validators/account'

export default class AccountsController {
  /**
   * GET /accounts?includeArchived=true → { data: Account[], meta: { netWorth } }
   */
  async index({ auth, request, serialize }: HttpContext) {
    const { includeArchived } = await request.validateUsing(listAccountsValidator, {
      data: request.qs(),
    })
    const { accounts, netWorth } = await AccountService.list(auth.getUserOrFail(), {
      includeArchived,
    })
    const data = await serialize.withoutWrapping(AccountTransformer.transform(accounts))
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

  async destroy({ auth, params, response }: HttpContext) {
    await AccountService.delete(auth.getUserOrFail(), params.id)
    return response.noContent()
  }
}

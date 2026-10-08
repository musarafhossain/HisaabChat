import type { HttpContext } from '@adonisjs/core/http'
import PeopleService from '#services/people_service'
import { personDto } from '#transformers/person_transformer'
import TransactionTransformer from '#transformers/transaction_transformer'
import {
  createPersonValidator,
  listPeopleValidator,
  settlePersonValidator,
  updatePersonValidator,
} from '#validators/person'

export default class PeopleController {
  /**
   * GET /people: people with balances; meta has the "You'll get / You owe" totals.
   */
  async index({ auth, request }: HttpContext) {
    const options = await request.validateUsing(listPeopleValidator, { data: request.qs() })
    const { items, youGet, youOwe } = await PeopleService.list(auth.getUserOrFail(), options)
    return { data: items.map((entry) => personDto(entry)), meta: { youGet, youOwe } }
  }

  async show({ auth, params }: HttpContext) {
    const entry = await PeopleService.find(auth.getUserOrFail(), params.id)
    return { data: personDto(entry) }
  }

  async store({ auth, request, response }: HttpContext) {
    const input = await request.validateUsing(createPersonValidator)
    const entry = await PeopleService.create(auth.getUserOrFail(), input)
    response.status(201)
    return { data: personDto(entry) }
  }

  async update({ auth, params, request }: HttpContext) {
    const changes = await request.validateUsing(updatePersonValidator)
    const entry = await PeopleService.update(auth.getUserOrFail(), params.id, changes)
    return { data: personDto(entry) }
  }

  async archive({ auth, params }: HttpContext) {
    const entry = await PeopleService.setArchived(auth.getUserOrFail(), params.id, true)
    return { data: personDto(entry) }
  }

  async unarchive({ auth, params }: HttpContext) {
    const entry = await PeopleService.setArchived(auth.getUserOrFail(), params.id, false)
    return { data: personDto(entry) }
  }

  /**
   * POST /people/:id/settle: records a COLLECT or REPAY for the balance.
   */
  async settle({ auth, params, request, response, serialize }: HttpContext) {
    const input = await request.validateUsing(settlePersonValidator)
    const transaction = await PeopleService.settle(auth.getUserOrFail(), params.id, input)
    response.status(201)
    return serialize(TransactionTransformer.transform(transaction))
  }
}

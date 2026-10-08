import type { HttpContext } from '@adonisjs/core/http'
import RecurringService from '#services/recurring_service'
import { occurrenceDto, ruleDto } from '#transformers/recurring_transformer'
import TransactionTransformer from '#transformers/transaction_transformer'
import {
  confirmOccurrenceValidator,
  createRuleValidator,
  updateRuleValidator,
  upcomingValidator,
} from '#validators/recurring'

export default class RecurringController {
  async index({ auth }: HttpContext) {
    const user = auth.getUserOrFail()
    const rules = await RecurringService.list(user)
    return { data: rules.map((rule) => ruleDto(rule, user)) }
  }

  async store({ auth, request, response }: HttpContext) {
    const user = auth.getUserOrFail()
    const input = await request.validateUsing(createRuleValidator)
    const rule = await RecurringService.create(user, input)
    response.status(201)
    return { data: ruleDto(rule, user) }
  }

  async update({ auth, params, request }: HttpContext) {
    const user = auth.getUserOrFail()
    const changes = await request.validateUsing(updateRuleValidator)
    const rule = await RecurringService.update(user, params.id, changes)
    return { data: ruleDto(rule, user) }
  }

  async destroy({ auth, params, response }: HttpContext) {
    await RecurringService.delete(auth.getUserOrFail(), params.id)
    response.status(204)
  }

  /**
   * GET /recurring/upcoming?days=7: pending occurrences to confirm or skip,
   * dates coming up, and lend/borrow due dates.
   */
  async upcoming({ auth, request }: HttpContext) {
    const user = auth.getUserOrFail()
    const { days } = await request.validateUsing(upcomingValidator, { data: request.qs() })
    const result = await RecurringService.upcoming(user, days ?? 7)
    return {
      data: {
        today: result.today,
        pending: result.pending.map((o) => occurrenceDto(o, user)),
        upcoming: result.upcoming.map(({ rule, date }) => ({ date, rule: ruleDto(rule, user) })),
        dues: result.dues,
      },
    }
  }

  async confirm({ auth, params, request, response, serialize }: HttpContext) {
    const input = await request.validateUsing(confirmOccurrenceValidator)
    const transaction = await RecurringService.confirm(auth.getUserOrFail(), params.id, input)
    response.status(201)
    return serialize(TransactionTransformer.transform(transaction))
  }

  async skip({ auth, params, response }: HttpContext) {
    await RecurringService.skip(auth.getUserOrFail(), params.id)
    response.status(204)
  }
}

import { DateTime } from 'luxon'
import type { HttpContext } from '@adonisjs/core/http'
import UserTransformer from '#transformers/user_transformer'
import { updateProfileValidator } from '#validators/user'

export default class MeController {
  async show({ auth, serialize }: HttpContext) {
    return serialize(UserTransformer.transform(auth.getUserOrFail()))
  }

  async update({ auth, request, serialize }: HttpContext) {
    const user = auth.getUserOrFail()
    const changes = await request.validateUsing(updateProfileValidator)

    user.merge(changes)
    await user.save()
    return serialize(UserTransformer.transform(user))
  }

  /**
   * Marks the onboarding wizard as finished (idempotent).
   */
  async completeOnboarding({ auth, serialize }: HttpContext) {
    const user = auth.getUserOrFail()
    if (!user.onboardedAt) {
      // DATETIME writes drop milliseconds; keep the response identical to later reads.
      user.onboardedAt = DateTime.utc().startOf('second')
      await user.save()
    }
    return serialize(UserTransformer.transform(user))
  }
}

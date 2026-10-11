import { DateTime } from 'luxon'
import type { HttpContext } from '@adonisjs/core/http'
import UserTransformer from '#transformers/user_transformer'
import AccountDeletionService from '#services/account_deletion_service'
import { deleteAccountValidator, updateProfileValidator } from '#validators/user'

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
   * DELETE /me: deletes the account and all its data (password required).
   */
  async destroy({ auth, request, response }: HttpContext) {
    const { password } = await request.validateUsing(deleteAccountValidator)
    await AccountDeletionService.delete(auth.getUserOrFail(), password)
    response.status(204)
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

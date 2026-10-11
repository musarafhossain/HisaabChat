import db from '@adonisjs/lucid/services/db'
import type { HttpContext } from '@adonisjs/core/http'
import User from '#models/user'
import UserTransformer from '#transformers/user_transformer'
import UserDefaultsService from '#services/user_defaults_service'
import PasswordResetService, { CODE_MINUTES } from '#services/password_reset_service'
import {
  forgotPasswordValidator,
  loginValidator,
  registerValidator,
  resetPasswordValidator,
} from '#validators/user'

export default class AuthController {
  /**
   * Creates the user and their default categories in one DB transaction,
   * then issues an access token for the device.
   */
  async register({ request, response, serialize }: HttpContext) {
    const { fullName, email, password, timezone, deviceName } =
      await request.validateUsing(registerValidator)

    const user = await db.transaction(async (trx) => {
      const created = await User.create(
        { fullName, email, password, ...(timezone ? { timezone } : {}) },
        { client: trx }
      )
      await UserDefaultsService.seed(created, trx)
      // Load DB defaults (currency, timezone, theme…) into the model.
      await created.refresh()
      return created
    })

    const token = await User.accessTokens.create(user, ['*'], { name: deviceName })
    response.status(201)
    return serialize({
      user: UserTransformer.transform(user),
      token: token.value!.release(),
    })
  }

  async login({ request, serialize }: HttpContext) {
    const { email, password, deviceName } = await request.validateUsing(loginValidator)

    const user = await User.verifyCredentials(email, password)
    const token = await User.accessTokens.create(user, ['*'], { name: deviceName })

    return serialize({
      user: UserTransformer.transform(user),
      token: token.value!.release(),
    })
  }

  /**
   * POST /auth/forgot-password: emails a 6-digit code if the account exists.
   * Always the same answer, so it doesn't reveal who has an account.
   */
  async forgotPassword({ request }: HttpContext) {
    const { email } = await request.validateUsing(forgotPasswordValidator)
    await PasswordResetService.request(email)
    return {
      data: {
        message: `If ${email} has an account, a code is on its way. It works for ${CODE_MINUTES} minutes.`,
        minutes: CODE_MINUTES,
      },
    }
  }

  /**
   * POST /auth/reset-password: new password with the emailed code. Signs
   * out every device; the app then signs in with the new password.
   */
  async resetPassword({ request }: HttpContext) {
    const input = await request.validateUsing(resetPasswordValidator)
    await PasswordResetService.reset(input)
    return { data: { message: 'Password changed. Sign in with your new password.' } }
  }

  /**
   * Revokes the token used for this request (this device only).
   */
  async logout({ auth }: HttpContext) {
    const user = auth.getUserOrFail()
    if (user.currentAccessToken) {
      await User.accessTokens.delete(user, user.currentAccessToken.identifier)
    }
    return { data: { message: 'Logged out' } }
  }

  /**
   * Revokes every token the user has (all devices).
   */
  async logoutAll({ auth }: HttpContext) {
    const user = auth.getUserOrFail()
    const tokens = await User.accessTokens.all(user)
    for (const token of tokens) {
      await User.accessTokens.delete(user, token.identifier)
    }
    return { data: { message: 'Logged out of all devices', revoked: tokens.length } }
  }
}

import { createHash, randomInt } from 'node:crypto'
import db from '@adonisjs/lucid/services/db'
import logger from '@adonisjs/core/services/logger'
import mail from '@adonisjs/mail/services/main'
import { Exception } from '@adonisjs/core/exceptions'
import { errors as vineErrors } from '@vinejs/vine'
import { DateTime } from 'luxon'
import { mailEnabled } from '#config/mail'
import PasswordResetCode from '#mails/password_reset_code'
import PasswordResetToken from '#models/password_reset_token'
import User from '#models/user'

/** How long an emailed code works. */
export const CODE_MINUTES = 15

const hashOf = (userId: string, code: string) =>
  createHash('sha256').update(`${userId}:${code}`).digest('hex')

const wrongCode = () =>
  new vineErrors.E_VALIDATION_ERROR([
    { field: 'code', message: 'That code is wrong or has expired', rule: 'code' },
  ])

/**
 * "Forgot password": email a 6-digit code, then set a new password with it.
 *
 * Only a hash of the code is stored (with the user id, so two users can get
 * the same digits). A new request replaces the old code; a used code can't
 * be used again; resetting signs out every device.
 */
export default class PasswordResetService {
  /**
   * Sends a code if the email belongs to someone. The answer is the same
   * either way, so nobody can find out which emails have accounts.
   */
  static async request(email: string) {
    if (!mailEnabled) {
      throw new Exception('Password reset isn’t available on this server yet', {
        status: 503,
        code: 'E_MAIL_DISABLED',
      })
    }
    const user = await User.findBy('email', email)
    if (!user) return

    const code = String(randomInt(0, 1_000_000)).padStart(6, '0')
    await db.transaction(async (trx) => {
      await trx
        .from('password_reset_tokens')
        .where('user_id', user.id)
        .whereNull('used_at')
        .delete()
      await PasswordResetToken.create(
        {
          userId: user.id,
          tokenHash: hashOf(user.id, code),
          expiresAt: DateTime.utc().plus({ minutes: CODE_MINUTES }),
        },
        { client: trx }
      )
    })

    try {
      await mail.send(new PasswordResetCode(user.email, user.fullName, code, CODE_MINUTES))
    } catch (error) {
      logger.error({ err: error }, 'password reset email failed')
      throw new Exception('Couldn’t send the email. Try again in a minute.', {
        status: 503,
        code: 'E_MAIL_FAILED',
      })
    }
  }

  /** Sets the new password when the code matches, then signs out everywhere. */
  static async reset(input: { email: string; code: string; password: string }) {
    const user = await User.findBy('email', input.email)
    if (!user) throw wrongCode()

    const token = await PasswordResetToken.query()
      .where('userId', user.id)
      .where('tokenHash', hashOf(user.id, input.code))
      .whereNull('usedAt')
      .where('expiresAt', '>', DateTime.utc().toJSDate())
      .first()
    if (!token) throw wrongCode()

    await db.transaction(async (trx) => {
      token.useTransaction(trx)
      token.usedAt = DateTime.utc()
      await token.save()
      user.useTransaction(trx)
      user.password = input.password // hashed by the model
      await user.save()
      await trx.from('auth_access_tokens').where('tokenable_id', user.id).delete()
    })
  }
}

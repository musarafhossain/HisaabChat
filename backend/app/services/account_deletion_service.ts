import db from '@adonisjs/lucid/services/db'
import hash from '@adonisjs/core/services/hash'
import { errors as vineErrors } from '@vinejs/vine'
import type User from '#models/user'

/**
 * "Delete my account": removes the user and every row they own, in one DB
 * transaction (all or nothing).
 *
 * Order matters: transactions and recurring rules reference accounts,
 * categories and people without ON DELETE actions (MySQL forbids them on
 * columns used in CHECK constraints), and sub-categories reference their
 * parent. Everything else cascades from `users`, but is deleted explicitly
 * here too so the order never depends on cascade timing.
 */
export default class AccountDeletionService {
  static async delete(user: User, password: string) {
    if (!(await hash.verify(user.password, password))) {
      throw new vineErrors.E_VALIDATION_ERROR([
        { field: 'password', message: 'That password isn’t right', rule: 'password' },
      ])
    }

    await db.transaction(async (trx) => {
      const userId = user.id
      const rules = trx.from('recurring_rules').select('id').where('user_id', userId)
      await trx.from('recurring_occurrences').whereIn('recurring_rule_id', rules).delete()
      await trx.from('transactions').where('user_id', userId).delete()
      await trx.from('recurring_rules').where('user_id', userId).delete()

      await trx
        .from('categories')
        .where('user_id', userId)
        .update({ parent_id: null, budget_id: null })
      await trx.from('categories').where('user_id', userId).delete()
      const budgets = trx.from('budgets').select('id').where('user_id', userId)
      await trx.from('budget_period_overrides').whereIn('budget_id', budgets).delete()
      await trx.from('budgets').where('user_id', userId).delete()

      await trx.from('people').where('user_id', userId).delete()
      await trx.from('accounts').where('user_id', userId).delete()
      await trx.from('password_reset_tokens').where('user_id', userId).delete()
      await trx.from('auth_access_tokens').where('tokenable_id', userId).delete()
      await trx.from('users').where('id', userId).delete()
    })
  }
}

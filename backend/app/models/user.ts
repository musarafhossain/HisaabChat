import { UserSchema } from '#database/schema'
import hash from '@adonisjs/core/services/hash'
import { compose } from '@adonisjs/core/helpers'
import { beforeCreate, hasMany } from '@adonisjs/lucid/orm'
import type { HasMany } from '@adonisjs/lucid/types/relations'
import { withAuthFinder } from '@adonisjs/auth/mixins/lucid'
import { type AccessToken, DbAccessTokensProvider } from '@adonisjs/auth/access_tokens'
import Account from '#models/account'
import Budget from '#models/budget'
import Category from '#models/category'
import Transaction from '#models/transaction'
import RecurringRule from '#models/recurring_rule'
import { assignUuid } from '#models/helpers'

export type Theme = 'SYSTEM' | 'LIGHT' | 'DARK'

export default class User extends compose(UserSchema, withAuthFinder(hash)) {
  static selfAssignPrimaryKey = true

  static accessTokens = DbAccessTokensProvider.forModel(User, {
    expiresIn: '30 days',
    prefix: 'oat_',
  })

  declare currentAccessToken?: AccessToken
  declare theme: Theme

  @hasMany(() => Account)
  declare accounts: HasMany<typeof Account>

  @hasMany(() => Category)
  declare categories: HasMany<typeof Category>

  @hasMany(() => Budget)
  declare budgets: HasMany<typeof Budget>

  @hasMany(() => Transaction)
  declare transactions: HasMany<typeof Transaction>

  @hasMany(() => RecurringRule)
  declare recurringRules: HasMany<typeof RecurringRule>

  @beforeCreate()
  static assignId(user: User) {
    assignUuid(user)
  }

  get initials() {
    const [first, last] = this.fullName ? this.fullName.split(' ') : this.email.split('@')
    if (first && last) {
      return `${first.charAt(0)}${last.charAt(0)}`.toUpperCase()
    }
    return `${first.slice(0, 2)}`.toUpperCase()
  }
}

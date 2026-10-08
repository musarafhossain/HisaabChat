import { AccountSchema } from '#database/schema'
import { beforeCreate, belongsTo, hasMany } from '@adonisjs/lucid/orm'
import type { BelongsTo, HasMany } from '@adonisjs/lucid/types/relations'
import User from '#models/user'
import Transaction from '#models/transaction'
import { assignUuid } from '#models/helpers'

export type AccountType = 'CASH' | 'BANK' | 'WALLET' | 'CREDIT_CARD' | 'SAVINGS' | 'OTHER'

export default class Account extends AccountSchema {
  static selfAssignPrimaryKey = true

  declare type: AccountType

  @belongsTo(() => User)
  declare user: BelongsTo<typeof User>

  @hasMany(() => Transaction)
  declare transactionsOut: HasMany<typeof Transaction>

  @hasMany(() => Transaction, { foreignKey: 'toAccountId' })
  declare transactionsIn: HasMany<typeof Transaction>

  @beforeCreate()
  static assignId(account: Account) {
    assignUuid(account)
  }

  /** Archived accounts are hidden from pickers and totals but keep their history. */
  get archived() {
    return this.archivedAt !== null && this.archivedAt !== undefined
  }
}

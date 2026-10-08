import { TransactionSchema } from '#database/schema'
import { beforeCreate, belongsTo } from '@adonisjs/lucid/orm'
import type { BelongsTo } from '@adonisjs/lucid/types/relations'
import User from '#models/user'
import Account from '#models/account'
import Category from '#models/category'
import RecurringRule from '#models/recurring_rule'
import { assignUuid } from '#models/helpers'

export type TransactionType = 'INCOME' | 'EXPENSE' | 'TRANSFER' | 'ADJUSTMENT'
export type AdjustmentDirection = 'INCREASE' | 'DECREASE'

export default class Transaction extends TransactionSchema {
  static selfAssignPrimaryKey = true

  declare type: TransactionType
  declare adjustmentDirection: AdjustmentDirection | null

  @belongsTo(() => User)
  declare user: BelongsTo<typeof User>

  @belongsTo(() => Account)
  declare account: BelongsTo<typeof Account>

  @belongsTo(() => Account, { foreignKey: 'toAccountId' })
  declare toAccount: BelongsTo<typeof Account>

  @belongsTo(() => Category)
  declare category: BelongsTo<typeof Category>

  @belongsTo(() => RecurringRule)
  declare recurringRule: BelongsTo<typeof RecurringRule>

  @beforeCreate()
  static assignId(transaction: Transaction) {
    assignUuid(transaction)
  }
}

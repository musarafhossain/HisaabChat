import { RecurringRuleSchema } from '#database/schema'
import { beforeCreate, belongsTo, hasMany } from '@adonisjs/lucid/orm'
import type { BelongsTo, HasMany } from '@adonisjs/lucid/types/relations'
import User from '#models/user'
import Account from '#models/account'
import Category from '#models/category'
import RecurringOccurrence from '#models/recurring_occurrence'
import { assignUuid } from '#models/helpers'

export type RecurringType = 'INCOME' | 'EXPENSE' | 'TRANSFER'
export type Frequency = 'DAILY' | 'WEEKLY' | 'MONTHLY' | 'YEARLY'

export default class RecurringRule extends RecurringRuleSchema {
  static selfAssignPrimaryKey = true

  declare type: RecurringType
  declare frequency: Frequency

  @belongsTo(() => User)
  declare user: BelongsTo<typeof User>

  @belongsTo(() => Account)
  declare account: BelongsTo<typeof Account>

  @belongsTo(() => Account, { foreignKey: 'toAccountId' })
  declare toAccount: BelongsTo<typeof Account>

  @belongsTo(() => Category)
  declare category: BelongsTo<typeof Category>

  @hasMany(() => RecurringOccurrence)
  declare occurrences: HasMany<typeof RecurringOccurrence>

  @beforeCreate()
  static assignId(rule: RecurringRule) {
    assignUuid(rule)
  }
}

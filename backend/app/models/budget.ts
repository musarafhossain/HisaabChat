import { BudgetSchema } from '#database/schema'
import { beforeCreate, belongsTo, hasMany } from '@adonisjs/lucid/orm'
import type { BelongsTo, HasMany } from '@adonisjs/lucid/types/relations'
import User from '#models/user'
import Category from '#models/category'
import BudgetPeriodOverride from '#models/budget_period_override'
import { assignUuid } from '#models/helpers'

export type BudgetPeriod = 'MONTHLY' | 'WEEKLY' | 'YEARLY'
export type BudgetKind = 'FIXED' | 'VARIABLE'

export default class Budget extends BudgetSchema {
  static selfAssignPrimaryKey = true

  declare period: BudgetPeriod
  declare kind: BudgetKind

  @belongsTo(() => User)
  declare user: BelongsTo<typeof User>

  /**
   * Categories counted toward this budget (categories.budget_id).
   */
  @hasMany(() => Category)
  declare categories: HasMany<typeof Category>

  @hasMany(() => BudgetPeriodOverride)
  declare overrides: HasMany<typeof BudgetPeriodOverride>

  @beforeCreate()
  static assignId(budget: Budget) {
    assignUuid(budget)
  }
}

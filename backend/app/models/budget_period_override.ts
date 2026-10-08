import { BudgetPeriodOverrideSchema } from '#database/schema'
import { beforeCreate, belongsTo } from '@adonisjs/lucid/orm'
import type { BelongsTo } from '@adonisjs/lucid/types/relations'
import Budget from '#models/budget'
import { assignUuid } from '#models/helpers'

export default class BudgetPeriodOverride extends BudgetPeriodOverrideSchema {
  static selfAssignPrimaryKey = true

  @belongsTo(() => Budget)
  declare budget: BelongsTo<typeof Budget>

  @beforeCreate()
  static assignId(override: BudgetPeriodOverride) {
    assignUuid(override)
  }
}

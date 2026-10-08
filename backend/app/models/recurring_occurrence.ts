import { RecurringOccurrenceSchema } from '#database/schema'
import { beforeCreate, belongsTo } from '@adonisjs/lucid/orm'
import type { BelongsTo } from '@adonisjs/lucid/types/relations'
import RecurringRule from '#models/recurring_rule'
import Transaction from '#models/transaction'
import { assignUuid } from '#models/helpers'

export type OccurrenceStatus = 'PENDING' | 'CONFIRMED' | 'SKIPPED'

export default class RecurringOccurrence extends RecurringOccurrenceSchema {
  static selfAssignPrimaryKey = true

  declare status: OccurrenceStatus

  @belongsTo(() => RecurringRule)
  declare rule: BelongsTo<typeof RecurringRule>

  @belongsTo(() => Transaction)
  declare transaction: BelongsTo<typeof Transaction>

  @beforeCreate()
  static assignId(occurrence: RecurringOccurrence) {
    assignUuid(occurrence)
  }
}

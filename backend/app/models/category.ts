import { CategorySchema } from '#database/schema'
import { beforeCreate, belongsTo, hasMany } from '@adonisjs/lucid/orm'
import type { BelongsTo, HasMany } from '@adonisjs/lucid/types/relations'
import User from '#models/user'
import Budget from '#models/budget'
import { assignUuid } from '#models/helpers'

export type CategoryType = 'INCOME' | 'EXPENSE'

export default class Category extends CategorySchema {
  static selfAssignPrimaryKey = true

  declare type: CategoryType

  @belongsTo(() => User)
  declare user: BelongsTo<typeof User>

  @belongsTo(() => Category, { foreignKey: 'parentId' })
  declare parent: BelongsTo<typeof Category>

  @hasMany(() => Category, { foreignKey: 'parentId' })
  declare children: HasMany<typeof Category>

  /**
   * The budget this (EXPENSE) category counts toward, if any.
   */
  @belongsTo(() => Budget)
  declare budget: BelongsTo<typeof Budget>

  @beforeCreate()
  static assignId(category: Category) {
    assignUuid(category)
  }

  /** Archived categories are hidden from pickers; past transactions keep them. */
  get archived() {
    return this.archivedAt !== null && this.archivedAt !== undefined
  }
}

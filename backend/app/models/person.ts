import { PersonSchema } from '#database/schema'
import { beforeCreate, belongsTo, hasMany } from '@adonisjs/lucid/orm'
import type { BelongsTo, HasMany } from '@adonisjs/lucid/types/relations'
import User from '#models/user'
import Transaction from '#models/transaction'
import { assignUuid } from '#models/helpers'

/** Someone the user lends money to or borrows from. */
export default class Person extends PersonSchema {
  static table = 'people'
  static selfAssignPrimaryKey = true

  @belongsTo(() => User)
  declare user: BelongsTo<typeof User>

  @hasMany(() => Transaction)
  declare transactions: HasMany<typeof Transaction>

  @beforeCreate()
  static assignId(person: Person) {
    assignUuid(person)
  }

  get archived() {
    return this.archivedAt !== null && this.archivedAt !== undefined
  }
}

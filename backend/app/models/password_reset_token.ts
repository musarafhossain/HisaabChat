import { PasswordResetTokenSchema } from '#database/schema'
import { beforeCreate, belongsTo } from '@adonisjs/lucid/orm'
import type { BelongsTo } from '@adonisjs/lucid/types/relations'
import User from '#models/user'
import { assignUuid } from '#models/helpers'

export default class PasswordResetToken extends PasswordResetTokenSchema {
  static selfAssignPrimaryKey = true

  @belongsTo(() => User)
  declare user: BelongsTo<typeof User>

  @beforeCreate()
  static assignId(token: PasswordResetToken) {
    assignUuid(token)
  }
}

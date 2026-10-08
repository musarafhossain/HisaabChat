import { BaseSchema } from '@adonisjs/lucid/schema'

export default class extends BaseSchema {
  protected tableName = 'password_reset_tokens'

  async up() {
    this.schema.createTable(this.tableName, (table) => {
      table.uuid('id').primary()
      table.uuid('user_id').notNullable().references('id').inTable('users').onDelete('CASCADE')
      table.string('token_hash', 64).notNullable().unique() // sha256 of the emailed token
      table.dateTime('expires_at', { precision: 3 }).notNullable()
      table.dateTime('used_at', { precision: 3 }).nullable()
      table.dateTime('created_at', { precision: 3 }).notNullable()
    })
  }

  async down() {
    this.schema.dropTable(this.tableName)
  }
}

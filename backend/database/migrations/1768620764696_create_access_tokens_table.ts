import { BaseSchema } from '@adonisjs/lucid/schema'

export default class extends BaseSchema {
  protected tableName = 'auth_access_tokens'

  async up() {
    this.schema.createTable(this.tableName, (table) => {
      table.increments('id')
      table.uuid('tokenable_id').notNullable().references('id').inTable('users').onDelete('CASCADE')

      table.string('type').notNullable()
      table.string('name').nullable()
      table.string('hash').notNullable()
      table.text('abilities').notNullable()
      table.dateTime('created_at', { precision: 3 }).nullable()
      table.dateTime('updated_at', { precision: 3 }).nullable()
      table.dateTime('last_used_at', { precision: 3 }).nullable()
      table.dateTime('expires_at', { precision: 3 }).nullable()
    })
  }

  async down() {
    this.schema.dropTable(this.tableName)
  }
}

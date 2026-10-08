import { BaseSchema } from '@adonisjs/lucid/schema'

export default class extends BaseSchema {
  protected tableName = 'people'

  async up() {
    this.schema.createTable(this.tableName, (table) => {
      table.uuid('id').primary()
      table.uuid('user_id').notNullable().references('id').inTable('users').onDelete('CASCADE')
      table.string('name', 60).notNullable()
      table.string('phone', 20).nullable()
      table.string('note', 200).nullable()
      table.string('color', 7).notNullable().defaultTo('#1DAA61')
      table.dateTime('archived_at', { precision: 3 }).nullable()
      table.dateTime('created_at', { precision: 3 }).notNullable()
      table.dateTime('updated_at', { precision: 3 }).notNullable()

      table.unique(['user_id', 'name'])
    })
  }

  async down() {
    this.schema.dropTable(this.tableName)
  }
}

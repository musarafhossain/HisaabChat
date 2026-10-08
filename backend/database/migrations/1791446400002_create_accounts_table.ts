import { BaseSchema } from '@adonisjs/lucid/schema'

export default class extends BaseSchema {
  protected tableName = 'accounts'

  async up() {
    this.schema.createTable(this.tableName, (table) => {
      table.uuid('id').primary()
      table.uuid('user_id').notNullable().references('id').inTable('users').onDelete('CASCADE')
      table.string('name', 60).notNullable()
      table
        .enum('type', ['CASH', 'BANK', 'WALLET', 'CREDIT_CARD', 'SAVINGS', 'OTHER'])
        .notNullable()
      table.bigInteger('opening_balance').notNullable().defaultTo(0) // paise; may be negative
      table.bigInteger('balance').notNullable().defaultTo(0) // cached current balance, paise
      table.bigInteger('credit_limit').nullable()
      table.string('color', 7).notNullable().defaultTo('#1DAA61')
      table.string('icon', 40).notNullable().defaultTo('wallet')
      table.boolean('include_in_total').notNullable().defaultTo(true)
      table.integer('sort_order').notNullable().defaultTo(0)
      table.dateTime('archived_at', { precision: 3 }).nullable()
      table.dateTime('created_at', { precision: 3 }).notNullable()
      table.dateTime('updated_at', { precision: 3 }).notNullable()

      table.unique(['user_id', 'name'])
      table.index(['user_id', 'archived_at'])
    })
  }

  async down() {
    this.schema.dropTable(this.tableName)
  }
}

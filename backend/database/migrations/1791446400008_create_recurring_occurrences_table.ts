import { BaseSchema } from '@adonisjs/lucid/schema'

export default class extends BaseSchema {
  protected tableName = 'recurring_occurrences'

  async up() {
    this.schema.createTable(this.tableName, (table) => {
      table.uuid('id').primary()
      table
        .uuid('recurring_rule_id')
        .notNullable()
        .references('id')
        .inTable('recurring_rules')
        .onDelete('CASCADE')
      table.date('due_date').notNullable()
      table.enum('status', ['PENDING', 'CONFIRMED', 'SKIPPED']).notNullable().defaultTo('PENDING')
      table
        .uuid('transaction_id')
        .nullable()
        .unique()
        .references('id')
        .inTable('transactions')
        .onDelete('SET NULL')
      table.dateTime('created_at', { precision: 3 }).notNullable()
      table.dateTime('updated_at', { precision: 3 }).notNullable()

      table.unique(['recurring_rule_id', 'due_date'])
      table.index(['status'])
    })
  }

  async down() {
    this.schema.dropTable(this.tableName)
  }
}

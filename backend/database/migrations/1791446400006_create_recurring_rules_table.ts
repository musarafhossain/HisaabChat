import { BaseSchema } from '@adonisjs/lucid/schema'

export default class extends BaseSchema {
  protected tableName = 'recurring_rules'

  async up() {
    this.schema.createTable(this.tableName, (table) => {
      table.uuid('id').primary()
      table.uuid('user_id').notNullable().references('id').inTable('users').onDelete('CASCADE')
      table.enum('type', ['INCOME', 'EXPENSE', 'TRANSFER']).notNullable()
      table.bigInteger('amount').notNullable()
      table.uuid('account_id').notNullable().references('id').inTable('accounts')
      table.uuid('to_account_id').nullable().references('id').inTable('accounts')
      table.uuid('category_id').nullable().references('id').inTable('categories')
      table.string('note', 200).nullable()

      table.enum('frequency', ['DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY']).notNullable()
      table.smallint('interval').notNullable().defaultTo(1)
      table.tinyint('day_of_month').nullable() // MONTHLY: 1..31, clamped to month end
      table.date('start_date').notNullable()
      table.date('end_date').nullable()
      table.dateTime('next_run_at', { precision: 3 }).notNullable() // UTC instant
      table.boolean('auto_create').notNullable().defaultTo(false)
      table.boolean('is_active').notNullable().defaultTo(true)
      table.dateTime('created_at', { precision: 3 }).notNullable()
      table.dateTime('updated_at', { precision: 3 }).notNullable()

      table.index(['is_active', 'next_run_at'])
      table.index(['user_id'])
    })

    this.schema.raw('ALTER TABLE recurring_rules ADD CONSTRAINT chk_rr_amount CHECK (amount > 0)')
  }

  async down() {
    this.schema.dropTable(this.tableName)
  }
}

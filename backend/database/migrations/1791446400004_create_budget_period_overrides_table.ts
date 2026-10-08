import { BaseSchema } from '@adonisjs/lucid/schema'

export default class extends BaseSchema {
  protected tableName = 'budget_period_overrides'

  async up() {
    this.schema.createTable(this.tableName, (table) => {
      table.uuid('id').primary()
      table.uuid('budget_id').notNullable().references('id').inTable('budgets').onDelete('CASCADE')
      table.date('period_start').notNullable() // local date the period starts on
      table.bigInteger('amount').notNullable()
      table.dateTime('created_at', { precision: 3 }).notNullable()
      table.dateTime('updated_at', { precision: 3 }).notNullable()

      table.unique(['budget_id', 'period_start'])
    })

    this.schema.raw(
      'ALTER TABLE budget_period_overrides ADD CONSTRAINT chk_bpo_amount CHECK (amount >= 0)'
    )
  }

  async down() {
    this.schema.dropTable(this.tableName)
  }
}

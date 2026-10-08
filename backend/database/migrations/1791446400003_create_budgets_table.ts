import { BaseSchema } from '@adonisjs/lucid/schema'

export default class extends BaseSchema {
  protected tableName = 'budgets'

  async up() {
    this.schema.createTable(this.tableName, (table) => {
      table.uuid('id').primary()
      table.uuid('user_id').notNullable().references('id').inTable('users').onDelete('CASCADE')
      table.string('name', 60).notNullable() // e.g. "Bike EMI + Petrol"
      table.bigInteger('amount').notNullable() // default amount per period, paise
      table.enum('period', ['MONTHLY', 'WEEKLY', 'YEARLY']).notNullable().defaultTo('MONTHLY')
      table.enum('kind', ['FIXED', 'VARIABLE']).notNullable().defaultTo('VARIABLE')
      table.date('start_date').notNullable()
      table.boolean('rollover').notNullable().defaultTo(false)
      table.tinyint('alert_percent').notNullable().defaultTo(80)
      table.string('color', 7).notNullable().defaultTo('#1DAA61')
      table.string('icon', 40).notNullable().defaultTo('savings')
      table.integer('sort_order').notNullable().defaultTo(0)
      table.dateTime('archived_at', { precision: 3 }).nullable()
      table.dateTime('created_at', { precision: 3 }).notNullable()
      table.dateTime('updated_at', { precision: 3 }).notNullable()

      table.unique(['user_id', 'name'])
      table.index(['user_id', 'archived_at'])
    })

    this.schema.raw(
      'ALTER TABLE budgets ADD CONSTRAINT chk_budgets_amount CHECK (amount >= 0), ADD CONSTRAINT chk_budgets_alert CHECK (alert_percent BETWEEN 1 AND 100)'
    )
  }

  async down() {
    this.schema.dropTable(this.tableName)
  }
}

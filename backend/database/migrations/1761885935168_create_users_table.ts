import { BaseSchema } from '@adonisjs/lucid/schema'

export default class extends BaseSchema {
  protected tableName = 'users'

  async up() {
    this.schema.createTable(this.tableName, (table) => {
      table.uuid('id').primary()
      table.string('full_name', 100).nullable()
      table.string('email', 254).notNullable().unique()
      table.string('password').notNullable()

      table.string('currency', 3).notNullable().defaultTo('INR')
      table.string('locale', 10).notNullable().defaultTo('en-IN')
      table.string('timezone', 64).notNullable().defaultTo('Asia/Kolkata')
      table.tinyint('month_start_day').notNullable().defaultTo(1)
      table.enum('theme', ['SYSTEM', 'LIGHT', 'DARK']).notNullable().defaultTo('SYSTEM')
      table.dateTime('onboarded_at', { precision: 3 }).nullable()

      table.dateTime('created_at', { precision: 3 }).notNullable()
      table.dateTime('updated_at', { precision: 3 }).notNullable()
    })

    this.schema.raw(
      'ALTER TABLE users ADD CONSTRAINT chk_users_month_start CHECK (month_start_day BETWEEN 1 AND 28)'
    )
  }

  async down() {
    this.schema.dropTable(this.tableName)
  }
}

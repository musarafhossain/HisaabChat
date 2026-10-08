import { BaseSchema } from '@adonisjs/lucid/schema'

export default class extends BaseSchema {
  protected tableName = 'categories'

  async up() {
    this.schema.createTable(this.tableName, (table) => {
      table.uuid('id').primary()
      table.uuid('user_id').notNullable().references('id').inTable('users').onDelete('CASCADE')
      table.string('name', 40).notNullable()
      table.enum('type', ['INCOME', 'EXPENSE']).notNullable()
      table.uuid('parent_id').nullable().references('id').inTable('categories') // one level of nesting

      /**
       * EXPENSE categories only. A category belongs to at most one budget, which
       * is how the "no double counting" rule is enforced by the data model.
       */
      table.uuid('budget_id').nullable().references('id').inTable('budgets').onDelete('SET NULL')

      table.string('color', 7).notNullable()
      table.string('icon', 40).notNullable()
      table.boolean('is_default').notNullable().defaultTo(false)
      table.integer('sort_order').notNullable().defaultTo(0)
      table.dateTime('archived_at', { precision: 3 }).nullable()
      table.dateTime('created_at', { precision: 3 }).notNullable()
      table.dateTime('updated_at', { precision: 3 }).notNullable()

      table.unique(['user_id', 'type', 'name'])
      table.index(['user_id', 'type', 'archived_at'])
      table.index(['budget_id'])
    })
  }

  async down() {
    this.schema.dropTable(this.tableName)
  }
}

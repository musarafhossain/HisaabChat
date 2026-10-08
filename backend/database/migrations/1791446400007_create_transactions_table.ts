import { BaseSchema } from '@adonisjs/lucid/schema'

export default class extends BaseSchema {
  protected tableName = 'transactions'

  async up() {
    this.schema.createTable(this.tableName, (table) => {
      table.uuid('id').primary() // client-generated UUID v7 (idempotent create)
      table.uuid('user_id').notNullable().references('id').inTable('users').onDelete('CASCADE')
      table.enum('type', ['INCOME', 'EXPENSE', 'TRANSFER', 'ADJUSTMENT']).notNullable()
      table.bigInteger('amount').notNullable() // paise, always > 0
      table.dateTime('date', { precision: 3 }).notNullable() // when it happened (UTC)
      table.string('note', 200).nullable()

      /**
       * No ON DELETE action on these three: MySQL forbids referential actions on
       * columns used in a CHECK constraint (chk_txn_shape below).
       */
      table.uuid('account_id').notNullable().references('id').inTable('accounts')
      table.uuid('to_account_id').nullable().references('id').inTable('accounts')
      table.uuid('category_id').nullable().references('id').inTable('categories')

      table.enum('adjustment_direction', ['INCREASE', 'DECREASE']).nullable()
      table
        .uuid('recurring_rule_id')
        .nullable()
        .references('id')
        .inTable('recurring_rules')
        .onDelete('SET NULL')
      table.date('occurrence_date').nullable()
      table.dateTime('created_at', { precision: 3 }).notNullable()
      table.dateTime('updated_at', { precision: 3 }).notNullable()

      table.unique(['recurring_rule_id', 'occurrence_date'])
      table.index(['user_id', 'date', 'id']) // list + cursor pagination
      table.index(['user_id', 'category_id', 'date']) // budgets & reports
      table.index(['account_id', 'date'])
      table.index(['to_account_id', 'date'])
    })

    this.schema.raw(`
      ALTER TABLE transactions
        ADD CONSTRAINT chk_txn_amount CHECK (amount > 0),
        ADD CONSTRAINT chk_txn_shape CHECK (
             (type IN ('INCOME', 'EXPENSE') AND category_id IS NOT NULL AND to_account_id IS NULL AND adjustment_direction IS NULL)
          OR (type = 'TRANSFER' AND to_account_id IS NOT NULL AND to_account_id <> account_id AND category_id IS NULL AND adjustment_direction IS NULL)
          OR (type = 'ADJUSTMENT' AND adjustment_direction IS NOT NULL AND category_id IS NULL AND to_account_id IS NULL)
        )
    `)
  }

  async down() {
    this.schema.dropTable(this.tableName)
  }
}

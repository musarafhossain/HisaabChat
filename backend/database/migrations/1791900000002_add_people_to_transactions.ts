import { BaseSchema } from '@adonisjs/lucid/schema'

/**
 * Lend & borrow (docs/05-Backend-Schema.md §3.1): four new transaction types
 * that move an account's balance and a person's balance, but never count as
 * income or expense.
 */
export default class extends BaseSchema {
  protected tableName = 'transactions'

  async up() {
    this.schema.raw('ALTER TABLE transactions DROP CONSTRAINT chk_txn_shape')
    this.schema.raw(`
      ALTER TABLE transactions
        MODIFY type ENUM('INCOME', 'EXPENSE', 'TRANSFER', 'ADJUSTMENT', 'LEND', 'BORROW', 'COLLECT', 'REPAY') NOT NULL
    `)
    this.schema.alterTable(this.tableName, (table) => {
      // No ON DELETE action: the column is used in chk_txn_shape.
      table.uuid('person_id').nullable().references('id').inTable('people').after('category_id')
      table.date('due_date').nullable().after('person_id') // LEND / BORROW only
      table.index(['person_id', 'date'])
    })
    this.schema.raw(`
      ALTER TABLE transactions
        ADD CONSTRAINT chk_txn_shape CHECK (
             (type IN ('INCOME', 'EXPENSE') AND category_id IS NOT NULL AND to_account_id IS NULL AND person_id IS NULL AND adjustment_direction IS NULL)
          OR (type = 'TRANSFER' AND to_account_id IS NOT NULL AND to_account_id <> account_id AND category_id IS NULL AND person_id IS NULL AND adjustment_direction IS NULL)
          OR (type = 'ADJUSTMENT' AND adjustment_direction IS NOT NULL AND category_id IS NULL AND to_account_id IS NULL AND person_id IS NULL)
          OR (type IN ('LEND', 'BORROW', 'COLLECT', 'REPAY') AND person_id IS NOT NULL AND category_id IS NULL AND to_account_id IS NULL AND adjustment_direction IS NULL)
        )
    `)
  }

  async down() {
    this.schema.raw('ALTER TABLE transactions DROP CONSTRAINT chk_txn_shape')
    this.schema.raw(`DELETE FROM transactions WHERE type IN ('LEND', 'BORROW', 'COLLECT', 'REPAY')`)
    this.schema.alterTable(this.tableName, (table) => {
      table.dropForeign(['person_id'])
      table.dropIndex(['person_id', 'date'])
      table.dropColumn('person_id')
      table.dropColumn('due_date')
    })
    this.schema.raw(`
      ALTER TABLE transactions
        MODIFY type ENUM('INCOME', 'EXPENSE', 'TRANSFER', 'ADJUSTMENT') NOT NULL,
        ADD CONSTRAINT chk_txn_shape CHECK (
             (type IN ('INCOME', 'EXPENSE') AND category_id IS NOT NULL AND to_account_id IS NULL AND adjustment_direction IS NULL)
          OR (type = 'TRANSFER' AND to_account_id IS NOT NULL AND to_account_id <> account_id AND category_id IS NULL AND adjustment_direction IS NULL)
          OR (type = 'ADJUSTMENT' AND adjustment_direction IS NOT NULL AND category_id IS NULL AND to_account_id IS NULL)
        )
    `)
  }
}

import { type SchemaRules } from '@adonisjs/lucid/types/schema_generator'

const columnsImport = { source: '#database/columns', namedImports: ['moneyColumn', 'boolColumn'] }

/**
 * TINYINT columns that hold small numbers rather than booleans.
 */
const smallNumber = { tsType: 'number', imports: [], decorators: [{ name: '@column' }] }

export default {
  types: {
    bigint: {
      tsType: 'number',
      imports: [columnsImport],
      decorators: [{ name: '@moneyColumn' }],
    },
    boolean: {
      tsType: 'boolean',
      imports: [columnsImport],
      decorators: [{ name: '@boolColumn' }],
    },
  },
  columns: {
    month_start_day: smallNumber,
    alert_percent: smallNumber,
    day_of_month: smallNumber,
  },
} satisfies SchemaRules

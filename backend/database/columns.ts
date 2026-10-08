import { column } from '@adonisjs/lucid/orm'
import type { ColumnOptions } from '@adonisjs/lucid/types/model'

/**
 * Money columns are BIGINT paise. mysql2 may hand them back as strings, so
 * always consume them as JS numbers (amounts stay far below 2^53).
 */
export function moneyColumn(options?: Partial<ColumnOptions>) {
  return column({
    consume: (value) => (value === null || value === undefined ? value : Number(value)),
    ...options,
  })
}

/**
 * MariaDB/MySQL store booleans as TINYINT(1) and return 0/1.
 */
export function boolColumn(options?: Partial<ColumnOptions>) {
  return column({
    consume: (value) => (value === null || value === undefined ? value : Boolean(value)),
    prepare: (value) => (value === null || value === undefined ? value : Boolean(value)),
    ...options,
  })
}

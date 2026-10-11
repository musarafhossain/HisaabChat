import { BaseSchema } from '@adonisjs/lucid/schema'

/**
 * The app's accent color (buttons, tabs, bubbles), chosen in
 * Settings → Appearance and synced across devices like the theme.
 */
const ACCENT_COLORS = [
  'GREEN',
  'TEAL',
  'BLUE',
  'INDIGO',
  'PURPLE',
  'PINK',
  'ORANGE',
  'AMBER',
  'CYAN',
  'SLATE',
] as const

export default class extends BaseSchema {
  protected tableName = 'users'

  async up() {
    this.schema.alterTable(this.tableName, (table) => {
      table
        .enum('accent_color', [...ACCENT_COLORS])
        .notNullable()
        .defaultTo('TEAL')
        .after('theme')
    })
  }

  async down() {
    this.schema.alterTable(this.tableName, (table) => {
      table.dropColumn('accent_color')
    })
  }
}

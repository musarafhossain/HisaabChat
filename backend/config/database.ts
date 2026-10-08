import app from '@adonisjs/core/services/app'
import env from '#start/env'
import { defineConfig } from '@adonisjs/lucid'

const dbConfig = defineConfig({
  /**
   * Default connection used for all queries.
   */
  connection: 'mysql',

  connections: {
    /**
     * MariaDB 10.4+ / MySQL 8.0.16+ (see docs/02-TRD.md §3.9 for the
     * compatibility rules every query and migration must follow).
     */
    mysql: {
      client: 'mysql2',
      connection: {
        host: env.get('DB_HOST'),
        port: env.get('DB_PORT'),
        user: env.get('DB_USER'),
        password: env.get('DB_PASSWORD'),
        database: env.get('DB_DATABASE'),
        charset: 'utf8mb4',

        /**
         * All DATETIME values are stored and read as UTC.
         */
        timezone: 'Z',

        /**
         * Money is stored as BIGINT paise. Return BIGINT and DECIMAL (e.g. SUM())
         * results as JS numbers. All amounts stay far below 2^53.
         */
        supportBigNumbers: true,
        bigNumberStrings: false,
        decimalNumbers: true,
      },

      migrations: {
        /**
         * Sort migration files naturally by filename.
         */
        naturalSort: true,

        /**
         * Paths containing migration files.
         */
        paths: ['database/migrations'],
      },

      schemaGeneration: {
        /**
         * Enable schema generation from Lucid models.
         */
        enabled: true,

        /**
         * Infrastructure tables that don't need Lucid models.
         */
        excludeTables: ['rate_limits'],

        /**
         * Custom schema rules file paths.
         */
        rulesPaths: ['./database/schema_rules.js'],
      },

      debug: app.inDev && env.get('DB_DEBUG', false),
    },
  },
})

export default dbConfig

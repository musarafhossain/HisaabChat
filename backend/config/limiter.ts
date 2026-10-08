import env from '#start/env'
import { defineConfig, stores } from '@adonisjs/limiter'

const limiterConfig = defineConfig({
  default: env.get('LIMITER_STORE'),
  stores: {
    /**
     * Database store: rate limiting data lives in the `rate_limits` table.
     */
    database: stores.database({
      tableName: 'rate_limits',
    }),

    /**
     * Memory store, used while running tests.
     */
    memory: stores.memory({}),
  },
})

export default limiterConfig

declare module '@adonisjs/limiter/types' {
  export interface LimitersList extends InferLimiters<typeof limiterConfig> {}
}

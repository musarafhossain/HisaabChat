import db from '@adonisjs/lucid/services/db'
import type { HttpContext } from '@adonisjs/core/http'

export default class HealthController {
  /**
   * Liveness + database check. Used by the Flutter app's connection check
   * and by the production deploy script.
   */
  async show({ response }: HttpContext) {
    let database: 'up' | 'down' = 'up'
    try {
      await db.rawQuery('SELECT 1')
    } catch {
      database = 'down'
    }

    const healthy = database === 'up'
    return response.status(healthy ? 200 : 503).send({
      data: {
        status: healthy ? 'ok' : 'degraded',
        database,
        time: new Date().toISOString(),
      },
    })
  }
}

/*
|--------------------------------------------------------------------------
| Define HTTP limiters
|--------------------------------------------------------------------------
|
| The "limiter.define" method creates an HTTP middleware to apply rate
| limits on a route or a group of routes.
|
*/

import app from '@adonisjs/core/services/app'
import limiter from '@adonisjs/limiter/services/main'

/**
 * Register / login: 10 attempts per minute per IP, then a 5 minute block.
 * Tests hit these endpoints far more often, so the limit is relaxed there.
 */
export const authThrottle = limiter.define('auth', (ctx) => {
  return limiter
    .allowRequests(app.inTest ? 1000 : 10)
    .every('1 minute')
    .usingKey(`auth_${ctx.request.ip()}`)
    .blockFor('5 minutes')
})

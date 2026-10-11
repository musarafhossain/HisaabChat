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
/**
 * Password reset, per email address on top of the per-IP limit above:
 * 3 codes per 15 minutes, and 5 tries at typing a code per 15 minutes
 * (so the 6 digits can't be guessed).
 */
export const forgotPasswordThrottle = limiter.define('forgotPassword', (ctx) => {
  return limiter
    .allowRequests(app.inTest ? 1000 : 3)
    .every('15 minutes')
    .usingKey(`forgot_${String(ctx.request.input('email', '')).trim().toLowerCase()}`)
})

export const resetPasswordThrottle = limiter.define('resetPassword', (ctx) => {
  return limiter
    .allowRequests(app.inTest ? 1000 : 5)
    .every('15 minutes')
    .usingKey(`reset_${String(ctx.request.input('email', '')).trim().toLowerCase()}`)
})

export const authThrottle = limiter.define('auth', (ctx) => {
  return limiter
    .allowRequests(app.inTest ? 1000 : 10)
    .every('1 minute')
    .usingKey(`auth_${ctx.request.ip()}`)
    .blockFor('5 minutes')
})

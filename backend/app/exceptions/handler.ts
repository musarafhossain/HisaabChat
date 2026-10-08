import app from '@adonisjs/core/services/app'
import { type HttpContext, ExceptionHandler } from '@adonisjs/core/http'
import { errors as vineErrors } from '@vinejs/vine'

type MaybeHttpError = { status?: unknown; code?: unknown; handle?: unknown; message?: unknown }

export default class HttpExceptionHandler extends ExceptionHandler {
  /**
   * In debug mode, the exception handler will display verbose errors
   * with pretty printed stack traces.
   */
  protected debug = !app.inProduction

  /**
   * Every error reaches clients as `{ errors: [{ message, code?, field? }] }`
   * (docs/02-TRD.md §4.1):
   * - validation errors keep VineJS's field-level format;
   * - errors that render themselves (auth, rate limiting) keep their own
   *   response, including headers such as Retry-After;
   * - other 4xx errors are normalized here instead of dumping a stack trace;
   * - 5xx errors show the debug page in development and a generic message
   *   in production.
   */
  async handle(error: unknown, ctx: HttpContext) {
    if (error instanceof vineErrors.E_VALIDATION_ERROR) return super.handle(error, ctx)

    const httpError = (typeof error === 'object' && error !== null ? error : {}) as MaybeHttpError
    if (typeof httpError.handle === 'function') return super.handle(error, ctx)

    const status = typeof httpError.status === 'number' ? httpError.status : 500
    if (status >= 500) {
      if (this.debug) return super.handle(error, ctx)
      return ctx.response.status(status).send({
        errors: [{ message: 'Something went wrong. Please try again.', code: 'E_SERVER_ERROR' }],
      })
    }

    const message = typeof httpError.message === 'string' ? httpError.message : 'Request failed'
    const code = typeof httpError.code === 'string' ? httpError.code : undefined
    return ctx.response.status(status).send({ errors: [{ message, ...(code ? { code } : {}) }] })
  }

  /**
   * The method is used to report error to the logging service or
   * the a third party error monitoring service.
   *
   * @note You should not attempt to send a response from this method.
   */
  async report(error: unknown, ctx: HttpContext) {
    return super.report(error, ctx)
  }
}

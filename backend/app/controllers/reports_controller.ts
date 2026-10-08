import type { HttpContext } from '@adonisjs/core/http'
import ReportService from '#services/report_service'
import TransactionTransformer from '#transformers/transaction_transformer'
import { byCategoryValidator, dashboardValidator, trendValidator } from '#validators/report'

export default class ReportsController {
  /**
   * GET /dashboard?month=YYYY-MM
   */
  async dashboard({ auth, request, serialize }: HttpContext) {
    const { month } = await request.validateUsing(dashboardValidator, { data: request.qs() })
    const { recent, ...summary } = await ReportService.dashboard(auth.getUserOrFail(), month)
    const items = await serialize.withoutWrapping(TransactionTransformer.transform(recent))
    return { data: { ...summary, recent: items } }
  }

  /**
   * GET /reports/categories?month=YYYY-MM&type=EXPENSE|INCOME
   */
  async byCategory({ auth, request }: HttpContext) {
    const { month, type } = await request.validateUsing(byCategoryValidator, { data: request.qs() })
    return {
      data: await ReportService.byCategory(auth.getUserOrFail(), type ?? 'EXPENSE', month),
    }
  }

  /**
   * GET /reports/trend?months=6&month=YYYY-MM
   */
  async trend({ auth, request }: HttpContext) {
    const { month, months } = await request.validateUsing(trendValidator, { data: request.qs() })
    return { data: await ReportService.trend(auth.getUserOrFail(), months ?? 6, month) }
  }
}

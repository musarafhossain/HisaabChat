import type { HttpContext } from '@adonisjs/core/http'
import ExportService from '#services/export_service'
import { exportCsvValidator } from '#validators/export'

/** `Content-Disposition` for a download (our file names are plain ASCII). */
const attachment = (fileName: string) => `attachment; filename="${fileName}"`

export default class ExportsController {
  /** GET /export/transactions.csv?from&to&accountId&personId (local dates, inclusive) */
  async transactionsCsv({ auth, request, response }: HttpContext) {
    const filters = await request.validateUsing(exportCsvValidator, { data: request.qs() })
    const csv = await ExportService.transactionsCsv(auth.getUserOrFail(), filters)
    response.header('Content-Type', 'text/csv; charset=utf-8')
    response.header('Content-Disposition', attachment(ExportService.csvFileName(filters)))
    return csv
  }

  /** GET /export/all.json: everything the user owns, as a backup. */
  async allJson({ auth, response }: HttpContext) {
    const user = auth.getUserOrFail()
    response.header('Content-Disposition', attachment(ExportService.jsonFileName(user)))
    return ExportService.all(user)
  }
}

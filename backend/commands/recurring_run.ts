import { BaseCommand } from '@adonisjs/core/ace'
import type { CommandOptions } from '@adonisjs/core/types/ace'

/**
 * Adds due recurring transactions (auto-add rules) and creates reminders
 * (remind-me rules) for every user. Idempotent; schedule it hourly, e.g.
 * `0 * * * * cd /srv/hisaabchat && node ace recurring:run`.
 * The API also catches up a user's rules whenever they open the app.
 */
export default class RecurringRun extends BaseCommand {
  static commandName = 'recurring:run'
  static description = 'Create due recurring transactions and reminders'

  static options: CommandOptions = {
    startApp: true,
  }

  async run() {
    const { default: RecurringService } = await import('#services/recurring_service')
    const created = await RecurringService.process()
    this.logger.success(`${created} recurring ${created === 1 ? 'entry' : 'entries'} processed`)
  }
}

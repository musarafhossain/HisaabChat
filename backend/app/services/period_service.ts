import { DateTime } from 'luxon'

/**
 * A budgeting period ("month") as seen by one user.
 *
 * Periods are computed in the user's time zone and month start day, then
 * converted to UTC instants for querying `transactions.date`. The server is
 * the only place this math happens, so every client shows the same numbers.
 */
export type Period = {
  /** "YYYY-MM": the calendar month the period starts in */
  month: string
  /** Inclusive UTC start instant */
  start: DateTime
  /** Exclusive UTC end instant */
  end: DateTime
  /** Local date the period starts on (YYYY-MM-DD) */
  periodStart: string
  /** Local date of the last day in the period (YYYY-MM-DD) */
  periodEnd: string
}

export type PeriodSettings = {
  timezone: string
  monthStartDay: number
}

const MONTH_PATTERN = /^(\d{4})-(0[1-9]|1[0-2])$/

export function isValidMonth(month: string): boolean {
  return MONTH_PATTERN.test(month)
}

/**
 * The period that starts in the given "YYYY-MM" month.
 */
export function periodForMonth(month: string, settings: PeriodSettings): Period {
  const match = MONTH_PATTERN.exec(month)
  if (!match) {
    throw new Error(`Invalid month "${month}", expected YYYY-MM`)
  }
  assertSettings(settings)

  const localStart = DateTime.fromObject(
    { year: Number(match[1]), month: Number(match[2]), day: settings.monthStartDay },
    { zone: settings.timezone }
  ).startOf('day')
  const localEnd = localStart.plus({ months: 1 })

  return {
    month,
    start: localStart.toUTC(),
    end: localEnd.toUTC(),
    periodStart: localStart.toISODate()!,
    periodEnd: localEnd.minus({ days: 1 }).toISODate()!,
  }
}

/**
 * The period containing the given instant (defaults to now).
 */
export function periodContaining(settings: PeriodSettings, instant: DateTime = DateTime.utc()) {
  assertSettings(settings)
  const local = instant.setZone(settings.timezone)
  const startMonth = local.day >= settings.monthStartDay ? local : local.minus({ months: 1 })
  return periodForMonth(startMonth.toFormat('yyyy-MM'), settings)
}

/**
 * The period immediately before / after the given one.
 */
export function shiftPeriod(period: Period, months: number, settings: PeriodSettings): Period {
  const [year, month] = period.month.split('-').map(Number)
  const shifted = DateTime.fromObject({ year, month, day: 1 }).plus({ months })
  return periodForMonth(shifted.toFormat('yyyy-MM'), settings)
}

/**
 * Days left in the period, counting today (in the user's time zone).
 * Returns the full length for future periods and 0 for past ones.
 */
export function daysLeft(
  period: Period,
  settings: PeriodSettings,
  now: DateTime = DateTime.utc()
): number {
  const zone = settings.timezone
  const today = now.setZone(zone).startOf('day')
  const first = DateTime.fromISO(period.periodStart, { zone })
  const last = DateTime.fromISO(period.periodEnd, { zone })

  if (today > last) return 0
  const from = today < first ? first : today
  return Math.round(last.diff(from, 'days').days) + 1
}

function assertSettings({ timezone, monthStartDay }: PeriodSettings) {
  if (!DateTime.local().setZone(timezone).isValid) {
    throw new Error(`Invalid time zone "${timezone}"`)
  }
  if (!Number.isInteger(monthStartDay) || monthStartDay < 1 || monthStartDay > 28) {
    throw new Error(`Invalid month start day ${monthStartDay}, expected 1-28`)
  }
}

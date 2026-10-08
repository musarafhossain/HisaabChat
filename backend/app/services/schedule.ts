import { DateTime } from 'luxon'

/**
 * Recurring schedules on calendar dates ("YYYY-MM-DD", the user's local
 * dates). Occurrence k is always computed from the start date, so a rule for
 * the 31st lands on Feb 28 (or 29) and goes back to the 31st in March.
 */
export type Frequency = 'DAILY' | 'WEEKLY' | 'MONTHLY' | 'YEARLY'

export type Schedule = {
  frequency: Frequency
  interval: number
  /** MONTHLY only: 1–31, clamped to the month's last day. */
  dayOfMonth?: number | null
  startDate: string
  endDate?: string | null
}

/** Safety net against runaway loops (≈ 27 years of daily entries). */
const MAX_STEPS = 10_000

const parse = (date: string) => DateTime.fromISO(date, { zone: 'utc' })

/** The k-th scheduled date (k = 0, 1, 2…), before applying start/end bounds. */
export function nthDate(schedule: Schedule, k: number): string {
  const start = parse(schedule.startDate)
  const step = k * Math.max(1, schedule.interval)
  switch (schedule.frequency) {
    case 'DAILY':
      return start.plus({ days: step }).toISODate()!
    case 'WEEKLY':
      return start.plus({ weeks: step }).toISODate()!
    case 'MONTHLY': {
      const month = start.startOf('month').plus({ months: step })
      const day = Math.min(schedule.dayOfMonth ?? start.day, month.daysInMonth!)
      return month.set({ day }).toISODate()!
    }
    case 'YEARLY': {
      const month = start.startOf('month').plus({ years: step })
      return month.set({ day: Math.min(start.day, month.daysInMonth!) }).toISODate()!
    }
  }
}

/**
 * Scheduled dates d with from ≤ d ≤ to (inclusive, ISO dates), within the
 * schedule's start and end dates, at most [limit] of them.
 */
export function datesBetween(schedule: Schedule, from: string, to: string, limit = 400) {
  const dates: string[] = []
  for (let k = 0; k < MAX_STEPS && dates.length < limit; k++) {
    const date = nthDate(schedule, k)
    if (date > to || (schedule.endDate && date > schedule.endDate)) break
    if (date >= from && date >= schedule.startDate) dates.push(date)
  }
  return dates
}

/** First scheduled date on or after [from], or null when the schedule has ended. */
export function nextOnOrAfter(schedule: Schedule, from: string): string | null {
  for (let k = 0; k < MAX_STEPS; k++) {
    const date = nthDate(schedule, k)
    if (schedule.endDate && date > schedule.endDate) return null
    if (date >= from && date >= schedule.startDate) return date
  }
  return null
}

/** First scheduled date strictly after [date]. */
export function nextAfter(schedule: Schedule, date: string): string | null {
  return nextOnOrAfter(schedule, parse(date).plus({ days: 1 }).toISODate()!)
}

import { test } from '@japa/runner'
import { DateTime } from 'luxon'
import {
  daysLeft,
  isValidMonth,
  periodContaining,
  periodForMonth,
  shiftPeriod,
} from '#services/period_service'

const IST = { timezone: 'Asia/Kolkata', monthStartDay: 1 }
const utc = (iso: string) => DateTime.fromISO(iso, { zone: 'utc' })

test.group('period_service / periodForMonth', () => {
  test('calendar month in IST maps to UTC bounds', ({ assert }) => {
    const p = periodForMonth('2026-10', IST)
    assert.equal(p.start.toISO(), '2026-09-30T18:30:00.000Z')
    assert.equal(p.end.toISO(), '2026-10-31T18:30:00.000Z')
    assert.equal(p.periodStart, '2026-10-01')
    assert.equal(p.periodEnd, '2026-10-31')
  })

  test('custom month start day (salary on the 25th)', ({ assert }) => {
    const p = periodForMonth('2026-10', { timezone: 'Asia/Kolkata', monthStartDay: 25 })
    assert.equal(p.periodStart, '2026-10-25')
    assert.equal(p.periodEnd, '2026-11-24')
  })

  test('February with month start day 28', ({ assert }) => {
    const p = periodForMonth('2027-02', { timezone: 'Asia/Kolkata', monthStartDay: 28 })
    assert.equal(p.periodStart, '2027-02-28')
    assert.equal(p.periodEnd, '2027-03-27')
  })

  test('rejects bad input', ({ assert }) => {
    assert.throws(() => periodForMonth('2026-13', IST))
    assert.throws(() => periodForMonth('2026-10', { timezone: 'Mars/Base', monthStartDay: 1 }))
    assert.throws(() => periodForMonth('2026-10', { timezone: 'Asia/Kolkata', monthStartDay: 29 }))
    assert.isFalse(isValidMonth('26-10'))
    assert.isTrue(isValidMonth('2026-10'))
  })
})

test.group('period_service / periodContaining', () => {
  test('23:30 IST on the last day still belongs to that month', ({ assert }) => {
    // 2026-10-31 23:30 IST == 2026-10-31 18:00 UTC
    assert.equal(periodContaining(IST, utc('2026-10-31T18:00:00Z')).month, '2026-10')
  })

  test('00:30 IST on the 1st belongs to the new month', ({ assert }) => {
    // 2026-11-01 00:30 IST == 2026-10-31 19:00 UTC
    assert.equal(periodContaining(IST, utc('2026-10-31T19:00:00Z')).month, '2026-11')
  })

  test('respects month start day', ({ assert }) => {
    const settings = { timezone: 'Asia/Kolkata', monthStartDay: 25 }
    assert.equal(periodContaining(settings, utc('2026-10-24T06:00:00Z')).month, '2026-09')
    assert.equal(periodContaining(settings, utc('2026-10-25T06:00:00Z')).month, '2026-10')
    assert.equal(periodContaining(settings, utc('2027-01-05T06:00:00Z')).month, '2026-12')
  })
})

test.group('period_service / helpers', () => {
  test('shiftPeriod moves across year boundaries', ({ assert }) => {
    const oct = periodForMonth('2026-10', IST)
    assert.equal(shiftPeriod(oct, 3, IST).month, '2027-01')
    assert.equal(shiftPeriod(oct, -10, IST).month, '2025-12')
  })

  test('daysLeft counts today in the user time zone', ({ assert }) => {
    const oct = periodForMonth('2026-10', IST)
    // 2026-10-20 10:00 IST -> Oct 20..31 = 12 days
    assert.equal(daysLeft(oct, IST, utc('2026-10-20T04:30:00Z')), 12)
    // last day
    assert.equal(daysLeft(oct, IST, utc('2026-10-31T10:00:00Z')), 1)
    // after the period
    assert.equal(daysLeft(oct, IST, utc('2026-11-02T10:00:00Z')), 0)
    // before the period: full length
    assert.equal(daysLeft(oct, IST, utc('2026-09-15T10:00:00Z')), 31)
  })
})

import { test } from '@japa/runner'
import { datesBetween, nextAfter, nextOnOrAfter, type Schedule } from '#services/schedule'

const monthly = (
  startDate: string,
  dayOfMonth?: number,
  extra: Partial<Schedule> = {}
): Schedule => ({
  frequency: 'MONTHLY',
  interval: 1,
  dayOfMonth,
  startDate,
  ...extra,
})

test.group('schedule', () => {
  test('monthly on the 31st clamps to short months and comes back', ({ assert }) => {
    assert.deepEqual(datesBetween(monthly('2026-01-31', 31), '2026-01-01', '2026-05-31'), [
      '2026-01-31',
      '2026-02-28',
      '2026-03-31',
      '2026-04-30',
      '2026-05-31',
    ])
    assert.deepEqual(datesBetween(monthly('2028-01-31', 31), '2028-02-01', '2028-02-29'), [
      '2028-02-29',
    ])
  })

  test('monthly day can differ from the start date; earlier days are skipped', ({ assert }) => {
    // Starts on the 10th but runs on the 5th: the first one is next month.
    assert.deepEqual(datesBetween(monthly('2026-10-10', 5), '2026-10-01', '2027-01-31'), [
      '2026-11-05',
      '2026-12-05',
      '2027-01-05',
    ])
  })

  test('daily, weekly and yearly with intervals', ({ assert }) => {
    const every2Days: Schedule = { frequency: 'DAILY', interval: 2, startDate: '2026-10-01' }
    assert.deepEqual(datesBetween(every2Days, '2026-10-01', '2026-10-07'), [
      '2026-10-01',
      '2026-10-03',
      '2026-10-05',
      '2026-10-07',
    ])
    const weekly: Schedule = { frequency: 'WEEKLY', interval: 1, startDate: '2026-10-05' }
    assert.deepEqual(datesBetween(weekly, '2026-10-06', '2026-10-31'), [
      '2026-10-12',
      '2026-10-19',
      '2026-10-26',
    ])
    const leapYearly: Schedule = { frequency: 'YEARLY', interval: 1, startDate: '2028-02-29' }
    assert.deepEqual(datesBetween(leapYearly, '2028-01-01', '2032-12-31'), [
      '2028-02-29',
      '2029-02-28',
      '2030-02-28',
      '2031-02-28',
      '2032-02-29',
    ])
  })

  test('end date stops the schedule', ({ assert }) => {
    const rule = monthly('2026-01-05', 5, { endDate: '2026-03-05' })
    assert.deepEqual(datesBetween(rule, '2026-01-01', '2026-12-31'), [
      '2026-01-05',
      '2026-02-05',
      '2026-03-05',
    ])
    assert.equal(nextAfter(rule, '2026-02-05'), '2026-03-05')
    assert.isNull(nextAfter(rule, '2026-03-05'))
  })

  test('next on or after', ({ assert }) => {
    const rule = monthly('2026-01-05', 5)
    assert.equal(nextOnOrAfter(rule, '2026-10-05'), '2026-10-05')
    assert.equal(nextOnOrAfter(rule, '2026-10-06'), '2026-11-05')
    assert.equal(nextOnOrAfter(rule, '2025-06-01'), '2026-01-05')
  })
})

import { test } from '@japa/runner'
import testUtils from '@adonisjs/core/services/test_utils'
import type { ApiClient } from '@japa/api-client'
import { DateTime } from 'luxon'
import { json, registerUser } from '#tests/helpers'
import { findBalanceDrift } from '#services/balance_service'
import RecurringService from '#services/recurring_service'

/** Dates in the default user's zone (IST). */
const ist = () => DateTime.now().setZone('Asia/Kolkata')
const today = () => ist().toISODate()!
const inDays = (n: number) => ist().plus({ days: n }).toISODate()!

async function setup(client: ApiClient) {
  const { token, userId } = await registerUser(client)
  const post = (path: string, body: object = {}) => client.post(path).bearerToken(token).json(body)
  const get = async (path: string) => {
    const body = json(await client.get(path).bearerToken(token))
    return body
  }
  const data = async (path: string) => {
    const body = await get(path)
    return body.data
  }
  const cash = json(
    await post('/api/v1/accounts', { name: 'Cash', type: 'CASH', openingBalance: 10_000_000 })
  ).data
  const categories = (await data('/api/v1/categories')) as Array<{ id: string; name: string }>
  const category = (name: string) => categories.find((c) => c.name === name)!.id
  const rule = (body: object) =>
    post('/api/v1/recurring', {
      type: 'EXPENSE',
      amount: 320_000,
      accountId: cash.id,
      categoryId: category('Bike EMI'),
      frequency: 'MONTHLY',
      startDate: today(),
      ...body,
    })
  const transactions = async () => (await data('/api/v1/transactions')) as any[]
  const balance = async () => {
    const account = await data(`/api/v1/accounts/${cash.id}`)
    return account.balance as number
  }
  const firstPending = async () => {
    const upcoming = await data('/api/v1/recurring/upcoming')
    return upcoming.pending[0]
  }
  return {
    token,
    userId,
    post,
    get,
    data,
    cash,
    category,
    rule,
    transactions,
    balance,
    firstPending,
  }
}

test.group('recurring', (group) => {
  group.each.setup(() => testUtils.db().withGlobalTransaction())

  test('an auto-add rule due today adds the transaction once', async ({ client, assert }) => {
    const s = await setup(client)
    const created = await s.rule({ autoCreate: true, note: 'EMI' })
    created.assertStatus(201)
    const rule = json(created).data
    assert.containsSubset(rule, {
      frequency: 'MONTHLY',
      dayOfMonth: ist().day,
      autoCreate: true,
      isActive: true,
      category: { name: 'Bike EMI' },
    })
    assert.equal(rule.nextDate, ist().plus({ months: 1 }).toISODate())

    let list = await s.transactions()
    assert.lengthOf(list, 1)
    assert.containsSubset(list[0], {
      type: 'EXPENSE',
      amount: 320_000,
      isRecurring: true,
      note: 'EMI',
    })
    assert.equal(await s.balance(), 10_000_000 - 320_000)

    // Running again (cron, another device) changes nothing.
    await RecurringService.process()
    await s.get('/api/v1/recurring')
    list = await s.transactions()
    assert.lengthOf(list, 1)
  })

  test('missed dates are caught up later, then the next date moves on', async ({
    client,
    assert,
  }) => {
    const s = await setup(client)
    const rule = json(await s.rule({ autoCreate: true, frequency: 'WEEKLY' })).data

    const later = DateTime.utc().plus({ days: 15 })
    const created = await RecurringService.process({ now: later })
    assert.equal(created, 2) // +7 and +14 days

    const list = await s.transactions()
    assert.lengthOf(list, 3)
    assert.equal(await s.balance(), 10_000_000 - 3 * 320_000)
    assert.deepEqual(await findBalanceDrift(s.userId), [])

    const rules = await s.data('/api/v1/recurring')
    assert.equal(rules[0].id, rule.id)
    assert.equal(rules[0].nextDate, inDays(21))
  })

  test('remind-me rules wait for Confirm or Skip', async ({ client, assert }) => {
    const s = await setup(client)
    await s.rule({ autoCreate: false, amount: 900_000, categoryId: s.category('Room Rent') })

    assert.lengthOf(await s.transactions(), 0)
    const upcoming = await s.data('/api/v1/recurring/upcoming')
    assert.equal(upcoming.today, today())
    assert.lengthOf(upcoming.pending, 1)
    const pending = upcoming.pending[0]
    assert.containsSubset(pending, {
      dueDate: today(),
      status: 'PENDING',
      rule: { amount: 900_000, category: { name: 'Room Rent' } },
    })

    // Confirm with a different amount this month.
    const confirmed = await s.post(`/api/v1/recurring/occurrences/${pending.id}/confirm`, {
      amount: 950_000,
    })
    confirmed.assertStatus(201)
    confirmed.assertBodyContains({ data: { amount: 950_000, isRecurring: true } })
    assert.equal(await s.balance(), 10_000_000 - 950_000)

    const twice = await s.post(`/api/v1/recurring/occurrences/${pending.id}/confirm`)
    twice.assertStatus(409)

    const after = await s.data('/api/v1/recurring/upcoming')
    assert.lengthOf(after.pending, 0)
  })

  test('skip leaves no transaction', async ({ client, assert }) => {
    const s = await setup(client)
    await s.rule({ autoCreate: false })
    const pending = await s.firstPending()

    const skipped = await client
      .post(`/api/v1/recurring/occurrences/${pending.id}/skip`)
      .bearerToken(s.token)
    skipped.assertStatus(204)
    assert.lengthOf(await s.transactions(), 0)
    assert.isUndefined(await s.firstPending())
  })

  test('"Repeat" on a saved transaction links it as the first occurrence', async ({
    client,
    assert,
  }) => {
    const s = await setup(client)
    const txn = json(
      await s.post('/api/v1/transactions', {
        type: 'EXPENSE',
        amount: 320_000,
        accountId: s.cash.id,
        categoryId: s.category('Bike EMI'),
        date: DateTime.utc().toISO(),
      })
    ).data

    const rule = await s.rule({ autoCreate: true, linkTransactionId: txn.id })
    rule.assertStatus(201)
    const list = await s.transactions()
    assert.lengthOf(list, 1)
    assert.containsSubset(list[0], { id: txn.id, isRecurring: true })
    assert.equal(json(rule).data.nextDate, ist().plus({ months: 1 }).toISODate())

    const again = await s.rule({ linkTransactionId: txn.id })
    again.assertStatus(422)
  })

  test('upcoming lists the next week and lend/borrow due dates', async ({ client, assert }) => {
    const s = await setup(client)
    await s.rule({ autoCreate: true, frequency: 'MONTHLY', startDate: inDays(3) })
    await s.rule({ autoCreate: false, startDate: inDays(30), categoryId: s.category('Education') })

    const amit = json(await s.post('/api/v1/people', { name: 'Amit' })).data
    await s.post('/api/v1/transactions', {
      type: 'LEND',
      amount: 100_000,
      accountId: s.cash.id,
      personId: amit.id,
      dueDate: inDays(2),
      date: DateTime.utc().toISO(),
    })

    let upcoming = await s.data('/api/v1/recurring/upcoming')
    assert.lengthOf(upcoming.upcoming, 1)
    assert.containsSubset(upcoming.upcoming[0], { date: inDays(3), rule: { amount: 320_000 } })
    assert.lengthOf(upcoming.dues, 1)
    assert.containsSubset(upcoming.dues[0], {
      type: 'LEND',
      dueDate: inDays(2),
      person: { name: 'Amit' },
    })

    // Part paid back: the due amount shrinks to what's left.
    await s.post('/api/v1/transactions', {
      type: 'COLLECT',
      amount: 40_000,
      accountId: s.cash.id,
      personId: amit.id,
      date: DateTime.utc().toISO(),
    })
    upcoming = await s.data('/api/v1/recurring/upcoming')
    assert.equal(upcoming.dues[0].amount, 60_000)

    // Once Amit pays back, the due date goes away.
    await s.post(`/api/v1/people/${amit.id}/settle`, { accountId: s.cash.id })
    upcoming = await s.data('/api/v1/recurring/upcoming')
    assert.lengthOf(upcoming.dues, 0)
  })

  test('rules are validated like transactions', async ({ client }) => {
    const s = await setup(client)
    const wrongType = await s.rule({ type: 'INCOME' }) // Bike EMI is an expense category
    wrongType.assertStatus(422)
    wrongType.assertBodyContains({ errors: [{ field: 'categoryId' }] })

    const backwards = await s.rule({ startDate: inDays(10), endDate: inDays(1) })
    backwards.assertStatus(422)
    backwards.assertBodyContains({ errors: [{ field: 'endDate' }] })
  })

  test('pause, edit and delete', async ({ client, assert }) => {
    const s = await setup(client)
    const rule = json(await s.rule({ autoCreate: true })).data

    const paused = await client
      .patch(`/api/v1/recurring/${rule.id}`)
      .bearerToken(s.token)
      .json({ isActive: false })
    paused.assertBodyContains({ data: { isActive: false, nextDate: null } })
    assert.equal(await RecurringService.process({ now: DateTime.utc().plus({ months: 2 }) }), 0)

    const resumed = await client
      .patch(`/api/v1/recurring/${rule.id}`)
      .bearerToken(s.token)
      .json({ isActive: true, amount: 350_000 })
    // Today already has its transaction, so the next free date is next month.
    resumed.assertBodyContains({
      data: { isActive: true, amount: 350_000, nextDate: ist().plus({ months: 1 }).toISODate() },
    })

    const deleted = await client.delete(`/api/v1/recurring/${rule.id}`).bearerToken(s.token)
    deleted.assertStatus(204)
    const list = await s.transactions()
    assert.lengthOf(list, 1) // what it already added stays
    assert.isFalse(list[0].isRecurring)
  })

  test('other users can’t touch your occurrences', async ({ client }) => {
    const s = await setup(client)
    await s.rule({ autoCreate: false })
    const pending = await s.firstPending()
    const other = await registerUser(client, 'Other')
    const peek = await client
      .post(`/api/v1/recurring/occurrences/${pending.id}/confirm`)
      .bearerToken(other.token)
      .json({})
    peek.assertStatus(404)
  })
})

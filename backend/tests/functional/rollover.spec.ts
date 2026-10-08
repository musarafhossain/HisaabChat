import { test } from '@japa/runner'
import testUtils from '@adonisjs/core/services/test_utils'
import type { ApiClient } from '@japa/api-client'
import db from '@adonisjs/lucid/services/db'
import { DateTime } from 'luxon'
import { json, registerUser } from '#tests/helpers'

/** Budgeting months for a default user (IST, month starts on the 1st). */
const nowIst = DateTime.now().setZone('Asia/Kolkata')
const monthAgo = (n: number) => nowIst.minus({ months: n }).startOf('month')
const at = (n: number) => monthAgo(n).plus({ days: 4, hours: 10 }).toISO()!

async function setup(client: ApiClient, rollover: boolean) {
  const { token } = await registerUser(client)
  const post = (path: string, body: object) => client.post(path).bearerToken(token).json(body)
  const cash = json(
    await post('/api/v1/accounts', { name: 'Cash', type: 'CASH', openingBalance: 10_000_000 })
  ).data
  const categories = json(await client.get('/api/v1/categories').bearerToken(token)).data as Array<{
    id: string
    name: string
  }>
  const petrol = categories.find((c) => c.name === 'Petrol')!.id
  const budget = json(
    await post('/api/v1/budgets', {
      name: 'Bike',
      amount: 500_000,
      rollover,
      categoryIds: [petrol],
    })
  ).data
  // Pretend the budget has existed for three months.
  await db
    .from('budgets')
    .where('id', budget.id)
    .update({ start_date: monthAgo(3).toISODate() })

  const spend = (amount: number, monthsAgo: number) =>
    post('/api/v1/transactions', {
      type: 'EXPENSE',
      amount,
      accountId: cash.id,
      categoryId: petrol,
      date: at(monthsAgo),
    })
  const overview = async () => {
    const body = json(await client.get('/api/v1/budgets').bearerToken(token))
    return body.data
  }
  const firstBudget = async () => {
    const result = await overview()
    return result.budgets[0]
  }
  return { token, budget, spend, overview, firstBudget, post }
}

test.group('budget rollover', (group) => {
  group.each.setup(() => testUtils.db().withGlobalTransaction())

  test('carries unspent money and overspending forward', async ({ client, assert }) => {
    const s = await setup(client, true)
    await s.spend(400_000, 3) // 1,000 left
    await s.spend(600_000, 2) // 1,000 over
    await s.spend(200_000, 1) // 3,000 left
    await s.spend(100_000, 0)

    const data = await s.overview()
    const bike = data.budgets[0]
    assert.containsSubset(bike, {
      rollover: true,
      budgeted: 500_000,
      rolloverIn: 300_000, // 1,000 − 1,000 + 3,000
      spent: 100_000,
      remaining: 700_000, // 5,000 + 3,000 − 1,000
      percent: 13,
      status: 'OK',
    })
    assert.equal(data.totals.budgeted, 800_000)
  })

  test('is off by default and can be switched on later', async ({ client, assert }) => {
    const s = await setup(client, false)
    await s.spend(100_000, 1)

    let bike = await s.firstBudget()
    assert.containsSubset(bike, { rollover: false, rolloverIn: 0, remaining: 500_000 })

    await client
      .patch(`/api/v1/budgets/${s.budget.id}`)
      .bearerToken(s.token)
      .json({ rollover: true })
    bike = await s.firstBudget()
    // Three earlier months: 5,000 + 4,000 + 5,000 unspent.
    assert.containsSubset(bike, { rollover: true, rolloverIn: 1_400_000, remaining: 1_900_000 })
  })

  test('overspending carried in can push a budget over', async ({ client, assert }) => {
    const s = await setup(client, true)
    await db
      .from('budgets')
      .where('id', s.budget.id)
      .update({ start_date: monthAgo(1).toISODate() })
    await s.spend(900_000, 1) // 4,000 over last month
    await s.spend(150_000, 0)

    const bike = await s.firstBudget()
    assert.containsSubset(bike, {
      rolloverIn: -400_000,
      spent: 150_000,
      remaining: -50_000,
      status: 'EXCEEDED',
    })
  })
})

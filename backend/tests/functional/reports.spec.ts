import { test } from '@japa/runner'
import testUtils from '@adonisjs/core/services/test_utils'
import type { ApiClient } from '@japa/api-client'
import { DateTime } from 'luxon'
import { json, registerUser } from '#tests/helpers'

/** Current budgeting month for a default user (IST, month starts on the 1st). */
const nowIst = DateTime.now().setZone('Asia/Kolkata')
const month = nowIst.toFormat('yyyy-MM')
const lastMonth = nowIst.minus({ months: 1 }).toFormat('yyyy-MM')
const day = (m: string, d: number) => `${m}-${String(d).padStart(2, '0')}T10:00:00+05:30`

async function setup(client: ApiClient) {
  const { token } = await registerUser(client)
  const post = (path: string, body: object) => client.post(path).bearerToken(token).json(body)
  const get = async (path: string) => {
    const body = json(await client.get(path).bearerToken(token))
    return body.data
  }
  const cash = json(
    await post('/api/v1/accounts', { name: 'Cash', type: 'CASH', openingBalance: 1_000_000 })
  ).data
  const bank = json(
    await post('/api/v1/accounts', { name: 'Bank', type: 'BANK', openingBalance: 5_000_000 })
  ).data
  const categories = (await get('/api/v1/categories')) as Array<{ id: string; name: string }>
  const category = (name: string) => categories.find((c) => c.name === name)!.id

  const add = (type: string, amount: number, name: string | null, date = day(month, 1)) =>
    post('/api/v1/transactions', {
      type,
      amount,
      accountId: cash.id,
      ...(type === 'TRANSFER' ? { toAccountId: bank.id } : { categoryId: category(name!) }),
      date,
    })

  return { token, get, post, add, category, cash, bank }
}

test.group('reports', (group) => {
  group.each.setup(() => testUtils.db().withGlobalTransaction())

  test('dashboard sums this month and ignores transfers', async ({ client, assert }) => {
    const s = await setup(client)
    await s.add('INCOME', 3_000_000, 'Salary')
    await s.add('EXPENSE', 120_000, 'Food & Groceries')
    await s.add('EXPENSE', 80_000, 'Petrol')
    await s.add('TRANSFER', 200_000, null)
    await s.add('EXPENSE', 999_900, 'Petrol', day(lastMonth, 15)) // other month
    await s.post('/api/v1/budgets', {
      name: 'Bike',
      amount: 200_000,
      categoryIds: [s.category('Petrol')],
    })

    const data = await s.get('/api/v1/dashboard')
    assert.equal(data.month, month)
    assert.equal(data.accountsCount, 2)
    assert.equal(data.netWorth, 6_000_000 + 3_000_000 - 120_000 - 80_000 - 999_900)
    assert.equal(data.income, 3_000_000)
    assert.equal(data.expense, 200_000)
    assert.equal(data.net, 2_800_000)
    assert.lengthOf(data.budgets, 1)
    assert.containsSubset(data.budgets[0], { name: 'Bike', spent: 80_000, percent: 40 })
    assert.lengthOf(data.recent, 5)
    assert.containsSubset(data.recent[0], { type: 'TRANSFER' })

    const previous = await s.get(`/api/v1/dashboard?month=${lastMonth}`)
    assert.equal(previous.expense, 999_900)
    assert.equal(previous.income, 0)
  })

  test('dashboard works for a brand-new user', async ({ client, assert }) => {
    const { token } = await registerUser(client)
    const response = await client.get('/api/v1/dashboard').bearerToken(token)
    response.assertStatus(200)
    const data = json(response).data
    assert.deepInclude(data, { netWorth: 0, accountsCount: 0, income: 0, expense: 0, net: 0 })
    assert.lengthOf(data.budgets, 0)
    assert.lengthOf(data.recent, 0)
  })

  test('spending by category is ranked with percentages', async ({ client, assert }) => {
    const s = await setup(client)
    await s.add('EXPENSE', 300_000, 'Food & Groceries')
    await s.add('EXPENSE', 100_000, 'Food & Groceries')
    await s.add('EXPENSE', 100_000, 'Petrol')
    await s.add('INCOME', 3_000_000, 'Salary')
    await s.add('EXPENSE', 50_000, 'Petrol', day(lastMonth, 3))

    const expense = await s.get('/api/v1/reports/categories')
    assert.equal(expense.type, 'EXPENSE')
    assert.equal(expense.total, 500_000)
    assert.isTrue(new Date(expense.from) < new Date(expense.to))
    assert.lengthOf(expense.items, 2)
    assert.containsSubset(expense.items[0], {
      name: 'Food & Groceries',
      total: 400_000,
      count: 2,
      percent: 80,
    })
    assert.containsSubset(expense.items[1], { name: 'Petrol', total: 100_000, percent: 20 })

    const income = await s.get('/api/v1/reports/categories?type=INCOME')
    assert.equal(income.total, 3_000_000)
    assert.containsSubset(income.items, [{ name: 'Salary', percent: 100 }])
  })

  test('trend returns one point per month, oldest first', async ({ client, assert }) => {
    const s = await setup(client)
    await s.add('INCOME', 1_000_000, 'Salary', day(lastMonth, 5))
    await s.add('EXPENSE', 400_000, 'Petrol', day(lastMonth, 6))
    await s.add('EXPENSE', 100_000, 'Petrol')

    const points = await s.get('/api/v1/reports/trend?months=3')
    assert.lengthOf(points, 3)
    assert.equal(points[2].month, month)
    assert.equal(points[1].month, lastMonth)
    assert.containsSubset(points[1], { income: 1_000_000, expense: 400_000, net: 600_000 })
    assert.containsSubset(points[2], { income: 0, expense: 100_000, net: -100_000 })
    assert.containsSubset(points[0], { income: 0, expense: 0, net: 0 })
  })

  test('reports validate input and require auth', async ({ client }) => {
    const { token } = await registerUser(client)
    const bad = await client.get('/api/v1/reports/categories?type=TRANSFER').bearerToken(token)
    bad.assertStatus(422)
    const badMonth = await client.get('/api/v1/dashboard?month=2026-13').bearerToken(token)
    badMonth.assertStatus(422)
    const tooMany = await client.get('/api/v1/reports/trend?months=99').bearerToken(token)
    tooMany.assertStatus(422)
    const anon = await client.get('/api/v1/dashboard')
    anon.assertStatus(401)
  })

  test('reports only include the signed-in user', async ({ client, assert }) => {
    const s = await setup(client)
    await s.add('EXPENSE', 100_000, 'Petrol')
    const other = await registerUser(client, 'Other')
    const data = json(await client.get('/api/v1/reports/categories').bearerToken(other.token)).data
    assert.equal(data.total, 0)
    assert.lengthOf(data.items, 0)
  })
})

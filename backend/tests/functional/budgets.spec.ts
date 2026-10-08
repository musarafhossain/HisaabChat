import { test } from '@japa/runner'
import testUtils from '@adonisjs/core/services/test_utils'
import type { ApiClient } from '@japa/api-client'
import { DateTime } from 'luxon'
import { json, registerUser } from '#tests/helpers'

/** Current budgeting month for a default user (IST, month starts on the 1st). */
const nowIst = DateTime.now().setZone('Asia/Kolkata')
const month = nowIst.toFormat('yyyy-MM')
const day = (d: number, time = '10:00') => `${month}-${String(d).padStart(2, '0')}T${time}:00+05:30`

async function setup(client: ApiClient) {
  const { token } = await registerUser(client)
  const post = (path: string, body: object) => client.post(path).bearerToken(token).json(body)
  const cash = json(
    await post('/api/v1/accounts', { name: 'Cash', type: 'CASH', openingBalance: 10_000_000 })
  ).data
  const categories = json(await client.get('/api/v1/categories').bearerToken(token)).data as Array<{
    id: string
    name: string
  }>
  const category = (name: string) => categories.find((c) => c.name === name)!.id

  const spend = async (amount: number, name: string, date = day(2)) =>
    json(
      await post('/api/v1/transactions', {
        type: 'EXPENSE',
        amount,
        accountId: cash.id,
        categoryId: category(name),
        date,
      })
    )

  const overview = async (m = month) =>
    json(await client.get(`/api/v1/budgets?month=${m}`).bearerToken(token)).data

  const budgets = async (m = month) => {
    const data = await overview(m)
    return data.budgets
  }

  return { token, post, category, spend, overview, budgets, cash }
}

test.group('budgets', (group) => {
  group.each.setup(() => testUtils.db().withGlobalTransaction())

  test('a budget covers several categories and totals their spending', async ({
    client,
    assert,
  }) => {
    const s = await setup(client)
    const created = await s.post('/api/v1/budgets', {
      name: 'Bike EMI + Petrol',
      amount: 500_000,
      categoryIds: [s.category('Bike EMI'), s.category('Petrol')],
    })
    created.assertStatus(201)
    created.assertBodyContains({
      data: { name: 'Bike EMI + Petrol', kind: 'VARIABLE', alertPercent: 80, spent: 0 },
    })

    await s.spend(320_000, 'Bike EMI')
    await s.spend(20_000, 'Petrol')
    await s.spend(54_000, 'Food & Groceries') // not in any budget

    const overview = await s.overview()
    assert.equal(overview.month, month)
    const bike = overview.budgets[0]
    assert.containsSubset(bike, {
      budgeted: 500_000,
      spent: 340_000,
      remaining: 160_000,
      percent: 68,
      status: 'OK',
    })
    assert.lengthOf(bike.categories, 2)
    assert.deepEqual(overview.totals, { budgeted: 500_000, spent: 340_000, remaining: 160_000 })
    assert.equal(overview.unbudgeted, 54_000)
  })

  test('warning at the alert level, exceeded over the limit, safe-to-spend for variable budgets', async ({
    client,
    assert,
  }) => {
    const s = await setup(client)
    await s.post('/api/v1/budgets', {
      name: 'Food',
      amount: 400_000,
      categoryIds: [s.category('Food & Groceries')],
    })
    await s.post('/api/v1/budgets', {
      name: 'Rent',
      amount: 600_000,
      kind: 'FIXED',
      categoryIds: [s.category('Room Rent')],
    })
    await s.spend(340_000, 'Food & Groceries')
    await s.spend(650_000, 'Room Rent')

    const [food, rent] = await s.budgets()
    assert.equal(food.status, 'WARNING')
    assert.equal(food.percent, 85)
    assert.isAtLeast(food.daysLeft, 1)
    assert.equal(food.safeToSpendPerDay, Math.floor(60_000 / food.daysLeft))

    assert.equal(rent.status, 'EXCEEDED')
    assert.equal(rent.remaining, -50_000)
    assert.isNull(rent.safeToSpendPerDay)
  })

  test('a category can only be in one budget', async ({ client }) => {
    const s = await setup(client)
    await s.post('/api/v1/budgets', {
      name: 'Bike',
      amount: 500_000,
      categoryIds: [s.category('Petrol')],
    })
    const conflict = await s.post('/api/v1/budgets', {
      name: 'Fuel',
      amount: 100_000,
      categoryIds: [s.category('Petrol')],
    })
    conflict.assertStatus(422)
    conflict.assertBodyContains({
      errors: [{ field: 'categoryIds', message: 'Petrol is already in the “Bike” budget' }],
    })

    const income = await s.post('/api/v1/budgets', {
      name: 'Salary',
      amount: 100,
      categoryIds: [s.category('Salary')],
    })
    income.assertStatus(422)
  })

  test('sub-categories count toward their parent’s budget', async ({ client, assert }) => {
    const s = await setup(client)
    const child = json(
      await s.post('/api/v1/categories', {
        name: 'Vegetables',
        type: 'EXPENSE',
        color: '#16A34A',
        icon: 'shopping_cart',
        parentId: s.category('Food & Groceries'),
      })
    ).data
    await s.post('/api/v1/budgets', {
      name: 'Food',
      amount: 400_000,
      categoryIds: [s.category('Food & Groceries')],
    })
    await s.post('/api/v1/transactions', {
      type: 'EXPENSE',
      amount: 4_000,
      accountId: s.cash.id,
      categoryId: child.id,
      date: day(2),
    })

    const [food] = await s.budgets()
    assert.equal(food.spent, 4_000)
  })

  test('month boundaries follow the user’s time zone', async ({ client, assert }) => {
    const s = await setup(client)
    await s.post('/api/v1/budgets', {
      name: 'Petrol',
      amount: 100_000,
      categoryIds: [s.category('Petrol')],
    })
    const lastDay = nowIst.endOf('month').day
    await s.spend(1_000, 'Petrol', day(lastDay, '23:30')) // still this month in IST
    const next = nowIst.plus({ months: 1 }).startOf('month')
    await s.spend(2_000, 'Petrol', next.set({ hour: 0, minute: 30 }).toISO()!) // next month

    const [petrol] = await s.budgets()
    assert.equal(petrol.spent, 1_000)
    const [nextMonth] = await s.budgets(next.toFormat('yyyy-MM'))
    assert.equal(nextMonth.spent, 2_000)
  })

  test('a one-month override changes only that month', async ({ client, assert }) => {
    const s = await setup(client)
    const id = json(
      await s.post('/api/v1/budgets', {
        name: 'Education',
        amount: 200_000,
        kind: 'FIXED',
        categoryIds: [s.category('Education')],
      })
    ).data.id

    const put = await client
      .put(`/api/v1/budgets/${id}/overrides/${month}`)
      .bearerToken(s.token)
      .json({ amount: 1_500_000 })
    put.assertStatus(204)
    const [withOverride] = await s.budgets()
    assert.containsSubset(withOverride, {
      budgeted: 1_500_000,
      amount: 200_000,
      hasOverride: true,
    })

    const next = nowIst.plus({ months: 1 }).toFormat('yyyy-MM')
    const [nextMonth] = await s.budgets(next)
    assert.equal(nextMonth.budgeted, 200_000)

    await client.delete(`/api/v1/budgets/${id}/overrides/${month}`).bearerToken(s.token)
    const [restored] = await s.budgets()
    assert.equal(restored.budgeted, 200_000)
  })

  test('detail lists counted expenses and six months of history', async ({ client, assert }) => {
    const s = await setup(client)
    const id = json(
      await s.post('/api/v1/budgets', {
        name: 'Food',
        amount: 400_000,
        categoryIds: [s.category('Food & Groceries'), s.category('Eating Out')],
      })
    ).data.id
    await s.spend(54_000, 'Food & Groceries')
    await s.spend(6_000, 'Eating Out', day(3))
    await s.spend(20_000, 'Petrol')

    const detail = json(await client.get(`/api/v1/budgets/${id}`).bearerToken(s.token)).data
    assert.equal(detail.spent, 60_000)
    assert.lengthOf(detail.transactions, 2)
    assert.equal(detail.transactions[0].category.name, 'Eating Out') // newest first
    assert.lengthOf(detail.history, 6)
    assert.deepEqual(detail.history.at(-1), { month, budgeted: 400_000, spent: 60_000 })
    assert.isNull(detail.history[0].budgeted) // before the budget existed
  })

  test('editing categories relinks them; archiving frees them and the name', async ({
    client,
    assert,
  }) => {
    const s = await setup(client)
    const id = json(
      await s.post('/api/v1/budgets', {
        name: 'Bike',
        amount: 500_000,
        categoryIds: [s.category('Bike EMI'), s.category('Petrol')],
      })
    ).data.id

    const edited = await client
      .patch(`/api/v1/budgets/${id}`)
      .bearerToken(s.token)
      .json({ categoryIds: [s.category('Bike EMI')], amount: 350_000 })
    edited.assertStatus(200)
    assert.lengthOf(json(edited).data.categories, 1)

    // Petrol is free again.
    const fuel = await s.post('/api/v1/budgets', {
      name: 'Fuel',
      amount: 100_000,
      categoryIds: [s.category('Petrol')],
    })
    fuel.assertStatus(201)

    const archived = await client.post(`/api/v1/budgets/${id}/archive`).bearerToken(s.token)
    archived.assertStatus(204)
    const remaining = await s.budgets()
    const names = remaining.map((b: { name: string }) => b.name)
    assert.deepEqual(names, ['Fuel'])

    const again = await s.post('/api/v1/budgets', {
      name: 'Bike',
      amount: 1,
      categoryIds: [s.category('Bike EMI')],
    })
    again.assertStatus(201)
  })

  test('new expenses report the budget alerts they trigger', async ({ client, assert }) => {
    const s = await setup(client)
    await s.post('/api/v1/budgets', {
      name: 'Food',
      amount: 100_000,
      categoryIds: [s.category('Food & Groceries')],
    })

    const quiet = await s.spend(50_000, 'Food & Groceries')
    assert.deepEqual(quiet.budgetAlerts, [])

    const warning = await s.spend(35_000, 'Food & Groceries')
    assert.containsSubset(warning.budgetAlerts, [{ name: 'Food', percent: 85, status: 'WARNING' }])

    const still = await s.spend(5_000, 'Food & Groceries')
    assert.deepEqual(still.budgetAlerts, []) // already past 80%

    const over = await s.spend(20_000, 'Food & Groceries')
    assert.containsSubset(over.budgetAlerts, [{ status: 'EXCEEDED', remaining: -10_000 }])
  })

  test("another user's budget is not found", async ({ client }) => {
    const owner = await setup(client)
    const other = await setup(client)
    const id = json(
      await owner.post('/api/v1/budgets', {
        name: 'Food',
        amount: 1,
        categoryIds: [owner.category('Food & Groceries')],
      })
    ).data.id

    const response = await client.get(`/api/v1/budgets/${id}`).bearerToken(other.token)
    response.assertStatus(404)
    const stealCategory = await other.post('/api/v1/budgets', {
      name: 'Mine',
      amount: 1,
      categoryIds: [owner.category('Food & Groceries')],
    })
    stealCategory.assertStatus(422)
  })
})

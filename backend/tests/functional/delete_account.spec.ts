import { test } from '@japa/runner'
import testUtils from '@adonisjs/core/services/test_utils'
import type { ApiClient } from '@japa/api-client'
import db from '@adonisjs/lucid/services/db'
import { DateTime } from 'luxon'
import { v7 as uuidv7 } from 'uuid'
import { json } from '#tests/helpers'

const PASSWORD = 'secret-password'

/** Registers a user and gives them one of everything. */
async function userWithEverything(client: ApiClient) {
  const email = `user.${uuidv7()}@example.com`
  const registered = json(
    await client.post('/api/v1/auth/register').json({
      fullName: 'Delete Me',
      email,
      password: PASSWORD,
      passwordConfirmation: PASSWORD,
    })
  ).data
  const token = registered.token as string
  const userId = registered.user.id as string
  const post = async (path: string, body: object) => {
    const response = await client.post(path).bearerToken(token).json(body)
    response.assertStatus(201)
    return json(response).data
  }
  const today = DateTime.now().setZone('Asia/Kolkata').toISODate()!
  const now = DateTime.utc().toISO()

  const cash = await post('/api/v1/accounts', {
    name: 'Cash',
    type: 'CASH',
    openingBalance: 100_000,
  })
  const bank = await post('/api/v1/accounts', {
    name: 'Bank',
    type: 'BANK',
    openingBalance: 500_000,
  })
  const categories = json(await client.get('/api/v1/categories').bearerToken(token)).data as Array<{
    id: string
    name: string
  }>
  const food = categories.find((c) => c.name === 'Food & Groceries')!.id
  const sub = await post('/api/v1/categories', {
    name: 'Snacks',
    type: 'EXPENSE',
    color: '#F59E0B',
    icon: 'fastfood',
    parentId: food,
  })
  const budget = await post('/api/v1/budgets', {
    name: 'Food',
    amount: 300_000,
    categoryIds: [food],
  })
  await client
    .put(`/api/v1/budgets/${budget.id}/overrides/${today.slice(0, 7)}`)
    .bearerToken(token)
    .json({ amount: 400_000 })
  await post('/api/v1/transactions', {
    type: 'EXPENSE',
    amount: 5_000,
    accountId: cash.id,
    categoryId: sub.id,
    date: now,
  })
  await post('/api/v1/transactions', {
    type: 'TRANSFER',
    amount: 10_000,
    accountId: bank.id,
    toAccountId: cash.id,
    date: now,
  })
  const amit = await post('/api/v1/people', { name: 'Amit' })
  await post('/api/v1/transactions', {
    type: 'LEND',
    amount: 2_000,
    accountId: cash.id,
    personId: amit.id,
    date: now,
  })
  await post('/api/v1/recurring', {
    type: 'EXPENSE',
    amount: 1_000,
    accountId: cash.id,
    categoryId: food,
    frequency: 'MONTHLY',
    startDate: today,
    autoCreate: false, // leaves a pending occurrence
  })
  await client
    .post(`/api/v1/accounts/${cash.id}/reconcile`)
    .bearerToken(token)
    .json({ actualBalance: 1 })
  return { email, token, userId }
}

/** Rows left in every table that belongs to a user. */
async function rowsOf(userId: string) {
  const count = async (table: string, column = 'user_id') => {
    const row = await db.from(table).where(column, userId).count('* as n').first()
    return Number(row?.n ?? 0)
  }
  const occurrences = await db
    .from('recurring_occurrences as o')
    .join('recurring_rules as r', 'r.id', 'o.recurring_rule_id')
    .where('r.user_id', userId)
    .count('* as n')
    .first()
  return {
    users: await count('users', 'id'),
    tokens: await count('auth_access_tokens', 'tokenable_id'),
    accounts: await count('accounts'),
    categories: await count('categories'),
    budgets: await count('budgets'),
    transactions: await count('transactions'),
    people: await count('people'),
    recurringRules: await count('recurring_rules'),
    occurrences: Number(occurrences?.n ?? 0),
  }
}

test.group('delete account', (group) => {
  group.each.setup(() => testUtils.db().withGlobalTransaction())

  test('deletes the user and everything they own, and nobody else’s', async ({
    client,
    assert,
  }) => {
    const me = await userWithEverything(client)
    const other = await userWithEverything(client)
    const before = await rowsOf(me.userId)
    const otherBefore = await rowsOf(other.userId)
    assert.isAbove(before.transactions, 3)
    assert.isAbove(before.occurrences, 0)

    const response = await client
      .delete('/api/v1/me')
      .bearerToken(me.token)
      .json({ password: PASSWORD })
    response.assertStatus(204)

    assert.deepEqual(await rowsOf(me.userId), {
      users: 0,
      tokens: 0,
      accounts: 0,
      categories: 0,
      budgets: 0,
      transactions: 0,
      people: 0,
      recurringRules: 0,
      occurrences: 0,
    })
    // The other user still has all of theirs.
    assert.deepEqual(await rowsOf(other.userId), otherBefore)
    const otherMe = await client.get('/api/v1/me').bearerToken(other.token)
    otherMe.assertStatus(200)

    // The old token is gone, and the email can be used again.
    const after = await client.get('/api/v1/me').bearerToken(me.token)
    after.assertStatus(401)
    const again = await client.post('/api/v1/auth/register').json({
      fullName: 'Back Again',
      email: me.email,
      password: PASSWORD,
      passwordConfirmation: PASSWORD,
    })
    again.assertStatus(201)
  })

  test('needs the right password, and keeps everything when it’s wrong', async ({
    client,
    assert,
  }) => {
    const me = await userWithEverything(client)
    const before = await rowsOf(me.userId)

    const wrong = await client
      .delete('/api/v1/me')
      .bearerToken(me.token)
      .json({ password: 'not-my-password' })
    wrong.assertStatus(422)
    wrong.assertBodyContains({ errors: [{ field: 'password' }] })

    const missing = await client.delete('/api/v1/me').bearerToken(me.token).json({})
    missing.assertStatus(422)

    assert.deepEqual(await rowsOf(me.userId), before)

    const anonymous = await client.delete('/api/v1/me').json({ password: PASSWORD })
    anonymous.assertStatus(401)
  })
})

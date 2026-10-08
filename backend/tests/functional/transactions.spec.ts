import { test } from '@japa/runner'
import testUtils from '@adonisjs/core/services/test_utils'
import type { ApiClient } from '@japa/api-client'
import type { Assert } from '@japa/assert'
import { v7 as uuidv7 } from 'uuid'
import { findBalanceDrift } from '#services/balance_service'
import { json, registerUser } from '#tests/helpers'

/**
 * A user with Cash (₹2,300), Bank (₹40,000) and their category ids.
 */
async function setup(client: ApiClient) {
  const { userId, token } = await registerUser(client)
  const post = (path: string, body: object) => client.post(path).bearerToken(token).json(body)

  const cash = json(
    await post('/api/v1/accounts', { name: 'Cash', type: 'CASH', openingBalance: 230_000 })
  ).data
  const bank = json(
    await post('/api/v1/accounts', { name: 'Bank', type: 'BANK', openingBalance: 4_000_000 })
  ).data
  const categories = json(await client.get('/api/v1/categories').bearerToken(token)).data as Array<{
    id: string
    name: string
  }>
  const category = (name: string) => categories.find((c) => c.name === name)!.id

  const balances = async () => {
    const list = json(await client.get('/api/v1/accounts').bearerToken(token)).data as Array<{
      id: string
      balance: number
    }>
    return Object.fromEntries(list.map((a) => [a.id === cash.id ? 'cash' : 'bank', a.balance]))
  }

  return { userId, token, cash, bank, category, balances, post }
}

const at = (iso: string) => iso // readability for dates in bodies

async function assertNoDrift(assert: Assert, userId: string) {
  assert.deepEqual(await findBalanceDrift(userId), [])
}

test.group('transactions / balances', (group) => {
  group.each.setup(() => testUtils.db().withGlobalTransaction())

  test('expense, income and transfer move balances correctly', async ({ client, assert }) => {
    const s = await setup(client)

    const expense = await s.post('/api/v1/transactions', {
      type: 'EXPENSE',
      amount: 12_000,
      accountId: s.cash.id,
      categoryId: s.category('Petrol'),
      date: at('2026-10-08T19:45:00+05:30'),
      note: '  Shell pump ',
    })
    expense.assertStatus(201)
    expense.assertBodyContains({
      data: {
        type: 'EXPENSE',
        amount: 12_000,
        date: '2026-10-08T14:15:00.000Z',
        note: 'Shell pump',
        account: { name: 'Cash' },
        category: { name: 'Petrol', type: 'EXPENSE' },
        toAccount: null,
      },
    })

    await s.post('/api/v1/transactions', {
      type: 'INCOME',
      amount: 3_500_000,
      accountId: s.bank.id,
      categoryId: s.category('Salary'),
      date: at('2026-10-01T09:00:00+05:30'),
    })
    const transfer = await s.post('/api/v1/transactions', {
      type: 'TRANSFER',
      amount: 200_000,
      accountId: s.bank.id,
      toAccountId: s.cash.id,
      date: at('2026-10-05T18:00:00+05:30'),
      note: 'ATM',
    })
    transfer.assertBodyContains({ data: { toAccount: { name: 'Cash' }, category: null } })

    assert.deepEqual(await s.balances(), {
      cash: 230_000 - 12_000 + 200_000,
      bank: 4_000_000 + 3_500_000 - 200_000,
    })
    await assertNoDrift(assert, s.userId)
  })

  test('editing amount, account and type re-applies balances', async ({ client, assert }) => {
    const s = await setup(client)
    const created = json(
      await s.post('/api/v1/transactions', {
        type: 'EXPENSE',
        amount: 50_000,
        accountId: s.cash.id,
        categoryId: s.category('Food & Groceries'),
        date: at('2026-10-08T10:00:00Z'),
      })
    ).data

    const patch = (body: object) =>
      client.patch(`/api/v1/transactions/${created.id}`).bearerToken(s.token).json(body)

    const amountEdit = await patch({ amount: 54_000 })
    amountEdit.assertStatus(200)
    assert.deepEqual(await s.balances(), { cash: 176_000, bank: 4_000_000 })

    const accountEdit = await patch({ accountId: s.bank.id })
    accountEdit.assertStatus(200)
    assert.deepEqual(await s.balances(), { cash: 230_000, bank: 3_946_000 })

    const toTransfer = await patch({ type: 'TRANSFER', toAccountId: s.cash.id })
    toTransfer.assertStatus(200)
    toTransfer.assertBodyContains({ data: { type: 'TRANSFER', category: null } })
    assert.deepEqual(await s.balances(), { cash: 284_000, bank: 3_946_000 })

    const toIncome = await patch({ type: 'INCOME', categoryId: s.category('Refund') })
    toIncome.assertBodyContains({ data: { type: 'INCOME', toAccount: null } })
    assert.deepEqual(await s.balances(), { cash: 230_000, bank: 4_054_000 })

    await assertNoDrift(assert, s.userId)
  })

  test('deleting reverses the balance effect', async ({ client, assert }) => {
    const s = await setup(client)
    const created = json(
      await s.post('/api/v1/transactions', {
        type: 'TRANSFER',
        amount: 100_000,
        accountId: s.cash.id,
        toAccountId: s.bank.id,
        date: at('2026-10-08T10:00:00Z'),
      })
    ).data

    const deleted = await client.delete(`/api/v1/transactions/${created.id}`).bearerToken(s.token)
    deleted.assertStatus(204)
    assert.deepEqual(await s.balances(), { cash: 230_000, bank: 4_000_000 })
    await assertNoDrift(assert, s.userId)
  })

  test('posting the same id twice is idempotent (and undo can reuse it)', async ({
    client,
    assert,
  }) => {
    const s = await setup(client)
    const id = uuidv7()
    const body = {
      id,
      type: 'EXPENSE',
      amount: 20_000,
      accountId: s.cash.id,
      categoryId: s.category('Petrol'),
      date: at('2026-10-08T10:00:00Z'),
    }

    const first = await s.post('/api/v1/transactions', body)
    first.assertStatus(201)
    const retry = await s.post('/api/v1/transactions', body)
    retry.assertStatus(200)
    assert.equal(json(retry).data.id, id)
    assert.deepEqual(await s.balances(), { cash: 210_000, bank: 4_000_000 })

    // Undo after delete: same id again creates it fresh.
    await client.delete(`/api/v1/transactions/${id}`).bearerToken(s.token)
    const recreated = await s.post('/api/v1/transactions', body)
    recreated.assertStatus(201)
    assert.deepEqual(await s.balances(), { cash: 210_000, bank: 4_000_000 })
    await assertNoDrift(assert, s.userId)
  })

  test('reconcile records the difference as an adjustment', async ({ client, assert }) => {
    const s = await setup(client)
    const reconcile = (actualBalance: number) =>
      client
        .post(`/api/v1/accounts/${s.cash.id}/reconcile`)
        .bearerToken(s.token)
        .json({ actualBalance })

    const down = await reconcile(200_000)
    down.assertBodyContains({
      data: { type: 'ADJUSTMENT', amount: 30_000, adjustmentDirection: 'DECREASE' },
    })
    const up = await reconcile(250_000)
    up.assertBodyContains({ data: { amount: 50_000, adjustmentDirection: 'INCREASE' } })
    const same = await reconcile(250_000)
    same.assertBody({ data: null })

    assert.deepEqual(await s.balances(), { cash: 250_000, bank: 4_000_000 })

    const adjustmentId = json(up).data.id
    const edit = await client
      .patch(`/api/v1/transactions/${adjustmentId}`)
      .bearerToken(s.token)
      .json({ amount: 1 })
    edit.assertStatus(422)
    await assertNoDrift(assert, s.userId)
  })
})

test.group('transactions / validation & isolation', (group) => {
  group.each.setup(() => testUtils.db().withGlobalTransaction())

  test('rejects invalid shapes', async ({ client, assert }) => {
    const s = await setup(client)
    const base = { amount: 1_000, accountId: s.cash.id, date: '2026-10-08T10:00:00Z' }

    const cases: Array<[object, string]> = [
      [{ ...base, type: 'EXPENSE' }, 'categoryId'],
      [{ ...base, type: 'EXPENSE', categoryId: s.category('Salary') }, 'categoryId'],
      [{ ...base, type: 'INCOME', categoryId: s.category('Petrol') }, 'categoryId'],
      [{ ...base, type: 'TRANSFER' }, 'toAccountId'],
      [{ ...base, type: 'TRANSFER', toAccountId: s.cash.id }, 'toAccountId'],
      [{ ...base, type: 'EXPENSE', categoryId: s.category('Petrol'), amount: 0 }, 'amount'],
      [{ ...base, type: 'EXPENSE', categoryId: s.category('Petrol'), amount: 10.5 }, 'amount'],
      [{ ...base, type: 'EXPENSE', categoryId: s.category('Petrol'), date: 'yesterday' }, 'date'],
      [{ ...base, type: 'ADJUSTMENT' }, 'type'],
    ]
    for (const [body, field] of cases) {
      const response = await s.post('/api/v1/transactions', body)
      assert.equal(response.status(), 422, JSON.stringify(body))
      assert.equal(json(response).errors[0].field, field, JSON.stringify(body))
    }
    assert.deepEqual(await s.balances(), { cash: 230_000, bank: 4_000_000 })
  })

  test('archived accounts take no new transactions', async ({ client }) => {
    const s = await setup(client)
    await client.post(`/api/v1/accounts/${s.cash.id}/archive`).bearerToken(s.token)

    const response = await s.post('/api/v1/transactions', {
      type: 'EXPENSE',
      amount: 1_000,
      accountId: s.cash.id,
      categoryId: s.category('Petrol'),
      date: '2026-10-08T10:00:00Z',
    })
    response.assertStatus(422)
    response.assertBodyContains({ errors: [{ field: 'accountId' }] })
  })

  test("other users' accounts, categories and transactions are off limits", async ({
    client,
    assert,
  }) => {
    const owner = await setup(client)
    const intruder = await setup(client)
    const created = json(
      await owner.post('/api/v1/transactions', {
        type: 'EXPENSE',
        amount: 1_000,
        accountId: owner.cash.id,
        categoryId: owner.category('Petrol'),
        date: '2026-10-08T10:00:00Z',
      })
    ).data

    const useTheirAccount = await intruder.post('/api/v1/transactions', {
      type: 'EXPENSE',
      amount: 1_000,
      accountId: owner.cash.id,
      categoryId: intruder.category('Petrol'),
      date: '2026-10-08T10:00:00Z',
    })
    useTheirAccount.assertStatus(422)

    const useTheirCategory = await intruder.post('/api/v1/transactions', {
      type: 'EXPENSE',
      amount: 1_000,
      accountId: intruder.cash.id,
      categoryId: owner.category('Petrol'),
      date: '2026-10-08T10:00:00Z',
    })
    useTheirCategory.assertStatus(422)

    for (const response of [
      await client.get(`/api/v1/transactions/${created.id}`).bearerToken(intruder.token),
      await client
        .patch(`/api/v1/transactions/${created.id}`)
        .bearerToken(intruder.token)
        .json({ amount: 5 }),
      await client.delete(`/api/v1/transactions/${created.id}`).bearerToken(intruder.token),
    ]) {
      response.assertStatus(404)
    }

    const reusedId = await intruder.post('/api/v1/transactions', {
      id: created.id,
      type: 'EXPENSE',
      amount: 1_000,
      accountId: intruder.cash.id,
      categoryId: intruder.category('Petrol'),
      date: '2026-10-08T10:00:00Z',
    })
    reusedId.assertStatus(409)

    const list = await client.get('/api/v1/transactions').bearerToken(intruder.token)
    assert.lengthOf(json(list).data, 0)
  })
})

test.group('transactions / listing', (group) => {
  group.each.setup(() => testUtils.db().withGlobalTransaction())

  test('filters, searches, totals and cursor pagination', async ({ client, assert }) => {
    const s = await setup(client)
    for (let day = 1; day <= 5; day++) {
      await s.post('/api/v1/transactions', {
        type: 'EXPENSE',
        amount: day * 1_000,
        accountId: s.cash.id,
        categoryId: s.category(day % 2 ? 'Petrol' : 'Food & Groceries'),
        date: `2026-10-0${day}T10:00:00Z`,
        note: day === 3 ? 'Big Bazaar weekly' : null,
      })
    }
    await s.post('/api/v1/transactions', {
      type: 'INCOME',
      amount: 50_000,
      accountId: s.bank.id,
      categoryId: s.category('Salary'),
      date: '2026-10-06T10:00:00Z',
    })
    await s.post('/api/v1/transactions', {
      type: 'TRANSFER',
      amount: 10_000,
      accountId: s.bank.id,
      toAccountId: s.cash.id,
      date: '2026-10-07T10:00:00Z',
    })

    const get = (qs: string) => client.get(`/api/v1/transactions${qs}`).bearerToken(s.token)

    const all = json(await get(''))
    assert.equal(all.data.length, 7)
    assert.deepEqual(all.meta.totals, { income: 50_000, expense: 15_000, count: 7 })
    assert.equal(all.data[0].type, 'TRANSFER') // newest first

    const cashThread = json(await get(`?accountId=${s.cash.id}`))
    assert.equal(cashThread.data.length, 6) // 5 expenses + incoming transfer

    const petrol = json(await get(`?categoryId=${s.category('Petrol')}`))
    assert.equal(petrol.meta.totals.expense, 1_000 + 3_000 + 5_000)

    const byNote = json(await get('?q=bazaar'))
    assert.equal(byNote.data.length, 1)
    const byCategoryName = json(await get('?q=groceries'))
    assert.equal(byCategoryName.data.length, 2)

    const range = json(await get('?from=2026-10-02T00:00:00Z&to=2026-10-04T00:00:00Z'))
    assert.equal(range.data.length, 2)

    const seen: string[] = []
    let cursor: string | null = null
    do {
      const page = json(await get(`?limit=3${cursor ? `&cursor=${cursor}` : ''}`))
      seen.push(...page.data.map((t: { id: string }) => t.id))
      cursor = page.meta.nextCursor
    } while (cursor)
    assert.deepEqual(
      seen,
      all.data.map((t: { id: string }) => t.id)
    )

    const badCursor = await get('?cursor=garbage')
    badCursor.assertStatus(422)
  })

  test('accounts list carries the last transaction preview', async ({ client, assert }) => {
    const s = await setup(client)
    await s.post('/api/v1/transactions', {
      type: 'EXPENSE',
      amount: 20_000,
      accountId: s.cash.id,
      categoryId: s.category('Petrol'),
      date: '2026-10-08T10:00:00Z',
    })
    await s.post('/api/v1/transactions', {
      type: 'TRANSFER',
      amount: 200_000,
      accountId: s.bank.id,
      toAccountId: s.cash.id,
      date: '2026-10-08T12:00:00Z',
    })

    const accounts = json(await client.get('/api/v1/accounts').bearerToken(s.token)).data
    const cash = accounts.find((a: { name: string }) => a.name === 'Cash')
    const bank = accounts.find((a: { name: string }) => a.name === 'Bank')
    assert.containsSubset(cash.lastTransaction, {
      type: 'TRANSFER',
      direction: 'IN',
      label: 'From Bank',
    })
    assert.containsSubset(bank.lastTransaction, {
      direction: 'OUT',
      label: 'To Cash',
      amount: 200_000,
    })
  })
})

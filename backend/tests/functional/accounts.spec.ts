import { test } from '@japa/runner'
import testUtils from '@adonisjs/core/services/test_utils'
import { DateTime } from 'luxon'
import Category from '#models/category'
import Transaction from '#models/transaction'
import { json, registerUser } from '#tests/helpers'

test.group('accounts', (group) => {
  group.each.setup(() => testUtils.db().withGlobalTransaction())

  test('creates accounts with type defaults and lists them with net worth', async ({
    client,
    assert,
  }) => {
    const { token } = await registerUser(client)

    const cash = await client
      .post('/api/v1/accounts')
      .bearerToken(token)
      .json({ name: 'Cash', type: 'CASH', openingBalance: 230_000 })
    cash.assertStatus(201)
    cash.assertBodyContains({
      data: {
        name: 'Cash',
        type: 'CASH',
        openingBalance: 230_000,
        balance: 230_000,
        icon: 'payments',
        color: '#16A34A',
        includeInTotal: true,
        archived: false,
        creditLimit: null,
      },
    })

    await client
      .post('/api/v1/accounts')
      .bearerToken(token)
      .json({ name: 'SBI Savings', type: 'BANK', openingBalance: 4_095_000 })

    const list = await client.get('/api/v1/accounts').bearerToken(token)
    list.assertStatus(200)
    const body = json(list)
    assert.deepEqual(
      body.data.map((a: { name: string }) => a.name),
      ['Cash', 'SBI Savings']
    )
    assert.equal(body.meta.netWorth, 4_325_000)
  })

  test('credit cards keep a limit and reduce net worth by the outstanding amount', async ({
    client,
  }) => {
    const { token } = await registerUser(client)
    await client
      .post('/api/v1/accounts')
      .bearerToken(token)
      .json({ name: 'Cash', type: 'CASH', openingBalance: 500_000 })

    const card = await client.post('/api/v1/accounts').bearerToken(token).json({
      name: 'HDFC Card',
      type: 'CREDIT_CARD',
      openingBalance: -120_000,
      creditLimit: 10_000_000,
    })
    card.assertStatus(201)
    card.assertBodyContains({
      data: { balance: -120_000, creditLimit: 10_000_000, icon: 'credit_card' },
    })

    const list = await client.get('/api/v1/accounts').bearerToken(token)
    list.assertBodyContains({ meta: { netWorth: 380_000 } })
  })

  test('accounts excluded from the total or archived do not count', async ({ client, assert }) => {
    const { token } = await registerUser(client)
    await client
      .post('/api/v1/accounts')
      .bearerToken(token)
      .json({ name: 'Cash', type: 'CASH', openingBalance: 100_000 })
    await client.post('/api/v1/accounts').bearerToken(token).json({
      name: 'Emergency Fund',
      type: 'SAVINGS',
      openingBalance: 5_000_000,
      includeInTotal: false,
    })
    const old = await client
      .post('/api/v1/accounts')
      .bearerToken(token)
      .json({ name: 'Old Wallet', type: 'WALLET', openingBalance: 20_000 })
    await client.post(`/api/v1/accounts/${json(old).data.id}/archive`).bearerToken(token)

    const active = await client.get('/api/v1/accounts').bearerToken(token)
    active.assertBodyContains({ meta: { netWorth: 100_000 } })
    assert.deepEqual(
      json(active).data.map((a: { name: string }) => a.name),
      ['Cash', 'Emergency Fund']
    )

    const all = await client.get('/api/v1/accounts?includeArchived=true').bearerToken(token)
    all.assertBodyContains({
      data: [{ name: 'Cash' }, { name: 'Emergency Fund' }, { archived: true }],
    })
    all.assertBodyContains({ meta: { netWorth: 100_000 } })
  })

  test('changing the opening balance shifts the current balance', async ({ client }) => {
    const { token } = await registerUser(client)
    const created = await client
      .post('/api/v1/accounts')
      .bearerToken(token)
      .json({ name: 'Cash', type: 'CASH', openingBalance: 100_000 })
    const id = json(created).data.id

    const updated = await client
      .patch(`/api/v1/accounts/${id}`)
      .bearerToken(token)
      .json({ openingBalance: 150_000, name: 'Wallet Cash', color: '#0EA5E9' })
    updated.assertStatus(200)
    updated.assertBodyContains({
      data: { name: 'Wallet Cash', openingBalance: 150_000, balance: 150_000, color: '#0EA5E9' },
    })
  })

  test('rejects duplicate names and invalid input', async ({ client, assert }) => {
    const { token } = await registerUser(client)
    await client.post('/api/v1/accounts').bearerToken(token).json({ name: 'Cash', type: 'CASH' })

    const duplicate = await client
      .post('/api/v1/accounts')
      .bearerToken(token)
      .json({ name: 'cash', type: 'CASH' })
    duplicate.assertStatus(422)
    duplicate.assertBodyContains({ errors: [{ field: 'name', rule: 'unique' }] })

    for (const body of [
      { name: '', type: 'CASH' },
      { name: 'Gold', type: 'GOLD' },
      { name: 'Paisa', type: 'CASH', openingBalance: 10.5 },
      { name: 'Paint', type: 'CASH', color: 'green' },
      { name: 'Icons', type: 'CASH', icon: 'Bad Icon!' },
    ]) {
      const response = await client.post('/api/v1/accounts').bearerToken(token).json(body)
      assert.equal(response.status(), 422, JSON.stringify(body))
    }
  })

  test('a credit limit is dropped for non-card accounts', async ({ client }) => {
    const { token } = await registerUser(client)
    const response = await client
      .post('/api/v1/accounts')
      .bearerToken(token)
      .json({ name: 'Cash', type: 'CASH', creditLimit: 50_000 })
    response.assertBodyContains({ data: { creditLimit: null } })
  })

  test('archive and unarchive', async ({ client }) => {
    const { token } = await registerUser(client)
    const created = await client
      .post('/api/v1/accounts')
      .bearerToken(token)
      .json({ name: 'Paytm', type: 'WALLET' })
    const id = json(created).data.id

    const archived = await client.post(`/api/v1/accounts/${id}/archive`).bearerToken(token)
    archived.assertBodyContains({ data: { archived: true } })

    const restored = await client.post(`/api/v1/accounts/${id}/unarchive`).bearerToken(token)
    restored.assertBodyContains({ data: { archived: false, archivedAt: null } })
  })

  test('delete works only while the account has no transactions', async ({ client, assert }) => {
    const { userId, token } = await registerUser(client)
    const empty = await client
      .post('/api/v1/accounts')
      .bearerToken(token)
      .json({ name: 'Spare', type: 'OTHER' })
    const used = await client
      .post('/api/v1/accounts')
      .bearerToken(token)
      .json({ name: 'Cash', type: 'CASH', openingBalance: 100_000 })

    const category = await Category.query()
      .where('userId', userId)
      .where('name', 'Petrol')
      .firstOrFail()
    await Transaction.create({
      userId,
      type: 'EXPENSE',
      amount: 12_000,
      date: DateTime.utc(),
      accountId: json(used).data.id,
      categoryId: category.id,
    })

    const deleted = await client
      .delete(`/api/v1/accounts/${json(empty).data.id}`)
      .bearerToken(token)
    deleted.assertStatus(204)

    const blocked = await client.delete(`/api/v1/accounts/${json(used).data.id}`).bearerToken(token)
    blocked.assertStatus(409)
    assert.include(json(blocked).errors[0].message, 'Archive it instead')
    assert.equal(json(blocked).errors[0].code, 'E_ACCOUNT_IN_USE')
  })

  test("users can't see or change each other's accounts", async ({ client }) => {
    const owner = await registerUser(client, 'Owner')
    const other = await registerUser(client, 'Other')
    const created = await client
      .post('/api/v1/accounts')
      .bearerToken(owner.token)
      .json({ name: 'Cash', type: 'CASH', openingBalance: 100_000 })
    const id = json(created).data.id

    const otherList = await client.get('/api/v1/accounts').bearerToken(other.token)
    otherList.assertBodyContains({ data: [], meta: { netWorth: 0 } })

    for (const response of [
      await client.get(`/api/v1/accounts/${id}`).bearerToken(other.token),
      await client.patch(`/api/v1/accounts/${id}`).bearerToken(other.token).json({ name: 'Mine' }),
      await client.post(`/api/v1/accounts/${id}/archive`).bearerToken(other.token),
      await client.delete(`/api/v1/accounts/${id}`).bearerToken(other.token),
    ]) {
      response.assertStatus(404)
    }
  })
})

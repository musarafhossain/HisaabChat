import { test } from '@japa/runner'
import testUtils from '@adonisjs/core/services/test_utils'
import type { ApiClient } from '@japa/api-client'
import { DateTime } from 'luxon'
import { json, registerUser } from '#tests/helpers'
import { findBalanceDrift } from '#services/balance_service'

const now = () => DateTime.utc().toISO()

async function setup(client: ApiClient) {
  const { token, userId } = await registerUser(client)
  const post = (path: string, body: object) => client.post(path).bearerToken(token).json(body)
  const get = async (path: string) => {
    const body = json(await client.get(path).bearerToken(token))
    return body
  }
  const data = async (path: string) => {
    const body = await get(path)
    return body.data
  }
  const cash = json(
    await post('/api/v1/accounts', { name: 'Cash', type: 'CASH', openingBalance: 1_000_000 })
  ).data
  const person = async (name: string) => json(await post('/api/v1/people', { name })).data
  const entry = (type: string, amount: number, personId: string, extra: object = {}) =>
    post('/api/v1/transactions', {
      type,
      amount,
      accountId: cash.id,
      personId,
      date: now(),
      ...extra,
    })
  const balanceOf = async (accountId: string) => {
    const body = await get(`/api/v1/accounts/${accountId}`)
    return body.data.balance as number
  }
  return { token, userId, post, get, data, cash, person, entry, balanceOf }
}

type Setup = Awaited<ReturnType<typeof setup>>

async function personBalance(s: Setup, id: string) {
  const person = await s.data(`/api/v1/people/${id}`)
  return person.balance as number
}

async function dashboardIncome(s: Setup) {
  const dashboard = await s.data('/api/v1/dashboard')
  return dashboard.income as number
}

test.group('people', (group) => {
  group.each.setup(() => testUtils.db().withGlobalTransaction())

  test('lending and borrowing move the account and the person balance', async ({
    client,
    assert,
  }) => {
    const s = await setup(client)
    const amit = await s.person('Amit')
    const riya = await s.person('Riya')

    const lent = await s.entry('LEND', 200_000, amit.id, { dueDate: '2026-12-31', note: 'Trip' })
    lent.assertStatus(201)
    lent.assertBodyContains({
      data: { type: 'LEND', person: { name: 'Amit' }, category: null, dueDate: '2026-12-31' },
    })
    await s.entry('COLLECT', 50_000, amit.id)
    await s.entry('BORROW', 30_000, riya.id)

    assert.equal(await s.balanceOf(s.cash.id), 1_000_000 - 200_000 + 50_000 + 30_000)

    const people = await s.get('/api/v1/people')
    assert.deepEqual(people.meta, { youGet: 150_000, youOwe: 30_000 })
    const byName = Object.fromEntries(people.data.map((p: any) => [p.name, p.balance]))
    assert.deepEqual(byName, { Amit: 150_000, Riya: -30_000 })

    // Never counted as income or expense.
    const dashboard = await s.get('/api/v1/dashboard')
    assert.equal(dashboard.data.income, 0)
    assert.equal(dashboard.data.expense, 0)

    // A person's thread is their transactions.
    const thread = await s.get(`/api/v1/transactions?personId=${amit.id}`)
    assert.lengthOf(thread.data, 2)

    assert.deepEqual(await findBalanceDrift(s.userId), [])
  })

  test('settle up records what squares the balance', async ({ client, assert }) => {
    const s = await setup(client)
    const amit = await s.person('Amit')
    const riya = await s.person('Riya')
    await s.entry('LEND', 100_000, amit.id)
    await s.entry('BORROW', 40_000, riya.id)

    const partial = await s.post(`/api/v1/people/${amit.id}/settle`, {
      accountId: s.cash.id,
      amount: 30_000,
    })
    partial.assertStatus(201)
    partial.assertBodyContains({ data: { type: 'COLLECT', amount: 30_000 } })

    const tooMuch = await s.post(`/api/v1/people/${amit.id}/settle`, {
      accountId: s.cash.id,
      amount: 90_000,
    })
    tooMuch.assertStatus(422)

    const rest = await s.post(`/api/v1/people/${amit.id}/settle`, { accountId: s.cash.id })
    rest.assertBodyContains({ data: { type: 'COLLECT', amount: 70_000 } })

    const repay = await s.post(`/api/v1/people/${riya.id}/settle`, { accountId: s.cash.id })
    repay.assertBodyContains({ data: { type: 'REPAY', amount: 40_000 } })

    const again = await s.post(`/api/v1/people/${riya.id}/settle`, { accountId: s.cash.id })
    again.assertStatus(422)

    const people = await s.get('/api/v1/people')
    assert.deepEqual(people.meta, { youGet: 0, youOwe: 0 })
    assert.equal(await s.balanceOf(s.cash.id), 1_000_000)
    assert.deepEqual(await findBalanceDrift(s.userId), [])
  })

  test('write-off clears what they owe as an expense, without moving money', async ({
    client,
    assert,
  }) => {
    const s = await setup(client)
    const amit = await s.person('Amit')
    await s.entry('LEND', 50_000, amit.id)
    const cashBefore = await s.balanceOf(s.cash.id)

    // Part of it first, then the rest (default amount = what's left).
    const part = await s.post(`/api/v1/people/${amit.id}/write-off`, {
      accountId: s.cash.id,
      amount: 20_000,
    })
    part.assertStatus(201)
    part.assertBodyContains({
      data: {
        settlement: {
          type: 'COLLECT',
          amount: 20_000,
          person: { name: 'Amit' },
          note: 'Written off',
        },
        writeOff: {
          type: 'EXPENSE',
          amount: 20_000,
          category: { name: 'Gifts' },
          note: 'Written off: Amit owed you',
        },
      },
    })
    assert.equal(await personBalance(s, amit.id), 30_000)

    const rest = await s.post(`/api/v1/people/${amit.id}/write-off`, {
      accountId: s.cash.id,
      note: 'He moved away',
    })
    rest.assertBodyContains({ data: { writeOff: { amount: 30_000, note: 'He moved away' } } })

    assert.equal(await personBalance(s, amit.id), 0)
    assert.equal(await s.balanceOf(s.cash.id), cashBefore)
    const dashboard = await s.get('/api/v1/dashboard')
    assert.equal(dashboard.data.expense, 50_000)
    assert.equal(dashboard.data.income, 0)

    const again = await s.post(`/api/v1/people/${amit.id}/write-off`, { accountId: s.cash.id })
    again.assertStatus(422)
    assert.deepEqual(await findBalanceDrift(s.userId), [])
  })

  test('write-off of what you owe is income; category and amount are checked', async ({
    client,
    assert,
  }) => {
    const s = await setup(client)
    const riya = await s.person('Riya')
    await s.entry('BORROW', 40_000, riya.id)
    const cashBefore = await s.balanceOf(s.cash.id)
    const categories = await s.data('/api/v1/categories')
    const byName = (name: string) => categories.find((c: any) => c.name === name).id

    const tooMuch = await s.post(`/api/v1/people/${riya.id}/write-off`, {
      accountId: s.cash.id,
      amount: 40_001,
    })
    tooMuch.assertStatus(422)
    tooMuch.assertBodyContains({ errors: [{ field: 'amount' }] })

    // An expense category can't hold a gift you received.
    const wrongType = await s.post(`/api/v1/people/${riya.id}/write-off`, {
      accountId: s.cash.id,
      categoryId: byName('Gifts'),
    })
    wrongType.assertStatus(422)
    assert.equal(await personBalance(s, riya.id), -40_000) // nothing half-saved

    const response = await s.post(`/api/v1/people/${riya.id}/write-off`, {
      accountId: s.cash.id,
      categoryId: byName('Pocket Money / Family'),
    })
    response.assertStatus(201)
    response.assertBodyContains({
      data: {
        settlement: { type: 'REPAY', amount: 40_000 },
        writeOff: {
          type: 'INCOME',
          category: { name: 'Pocket Money / Family' },
          note: 'Written off: you owed Riya',
        },
      },
    })
    assert.equal(await personBalance(s, riya.id), 0)
    assert.equal(await s.balanceOf(s.cash.id), cashBefore)
    assert.equal(await dashboardIncome(s), 40_000)
    assert.deepEqual(await findBalanceDrift(s.userId), [])

    const other = await registerUser(client, 'Someone else')
    const notYours = await client
      .post(`/api/v1/people/${riya.id}/write-off`)
      .bearerToken(other.token)
      .json({ accountId: s.cash.id })
    notYours.assertStatus(404)
  })

  test('editing and deleting entries keep balances right', async ({ client, assert }) => {
    const s = await setup(client)
    const amit = await s.person('Amit')
    const lent = json(await s.entry('LEND', 100_000, amit.id)).data

    await client
      .patch(`/api/v1/transactions/${lent.id}`)
      .bearerToken(s.token)
      .json({ type: 'BORROW', amount: 60_000 })
    assert.equal(await s.balanceOf(s.cash.id), 1_060_000)
    const person = await s.data(`/api/v1/people/${amit.id}`)
    assert.equal(person.balance, -60_000)

    await client.delete(`/api/v1/transactions/${lent.id}`).bearerToken(s.token)
    assert.equal(await s.balanceOf(s.cash.id), 1_000_000)
    assert.deepEqual(await findBalanceDrift(s.userId), [])
  })

  test('people entries need a person; due dates only stay on lend/borrow', async ({
    client,
    assert,
  }) => {
    const s = await setup(client)
    const missing = await s.post('/api/v1/transactions', {
      type: 'LEND',
      amount: 100,
      accountId: s.cash.id,
      date: now(),
    })
    missing.assertStatus(422)
    missing.assertBodyContains({ errors: [{ field: 'personId' }] })

    const amit = await s.person('Amit')
    const collect = json(await s.entry('COLLECT', 100, amit.id, { dueDate: '2026-12-31' })).data
    assert.isNull(collect.dueDate)
  })

  test('names are unique; archiving needs a settled balance', async ({ client }) => {
    const s = await setup(client)
    const amit = await s.person('Amit')
    const dup = await s.post('/api/v1/people', { name: 'Amit' })
    dup.assertStatus(422)
    dup.assertBodyContains({ errors: [{ field: 'name' }] })

    await s.entry('LEND', 1000, amit.id)
    const blocked = await client.post(`/api/v1/people/${amit.id}/archive`).bearerToken(s.token)
    blocked.assertStatus(422)

    await s.post(`/api/v1/people/${amit.id}/settle`, { accountId: s.cash.id })
    const archived = await client.post(`/api/v1/people/${amit.id}/archive`).bearerToken(s.token)
    archived.assertStatus(200)
    archived.assertBodyContains({ data: { archived: true } })

    const late = await s.entry('LEND', 1000, amit.id)
    late.assertStatus(422)
  })

  test('people are private to their owner', async ({ client }) => {
    const s = await setup(client)
    const amit = await s.person('Amit')
    const other = await registerUser(client, 'Other')
    const peek = await client.get(`/api/v1/people/${amit.id}`).bearerToken(other.token)
    peek.assertStatus(404)
  })
})

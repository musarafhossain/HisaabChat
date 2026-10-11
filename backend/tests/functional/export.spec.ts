import { test } from '@japa/runner'
import testUtils from '@adonisjs/core/services/test_utils'
import type { ApiClient } from '@japa/api-client'
import { json, registerUser } from '#tests/helpers'

type Ids = { token: string; cash: string; bank: string; food: string; snacks: string; amit: string }

/** Cash + Bank, a Food sub-category, a person and four transactions on 1–2 Oct 2026 (IST). */
async function setup(client: ApiClient): Promise<Ids> {
  const { token } = await registerUser(client, 'Asha')
  const post = async (path: string, body: object) => {
    const response = await client.post(path).bearerToken(token).json(body)
    response.assertStatus(201)
    return json(response).data.id as string
  }
  const cash = await post('/api/v1/accounts', {
    name: 'Cash',
    type: 'CASH',
    openingBalance: 100_000,
  })
  const bank = await post('/api/v1/accounts', {
    name: 'Bank, SBI',
    type: 'BANK',
    openingBalance: 0,
  })
  const categories = json(await client.get('/api/v1/categories').bearerToken(token)).data as Array<{
    id: string
    name: string
  }>
  const food = categories.find((c) => c.name === 'Food & Groceries')!.id
  const snacks = await post('/api/v1/categories', {
    name: 'Snacks',
    type: 'EXPENSE',
    color: '#F59E0B',
    icon: 'fastfood',
    parentId: food,
  })
  const amit = await post('/api/v1/people', { name: 'Amit' })

  // 30 Sep 23:30 IST is still September there.
  await post('/api/v1/transactions', {
    type: 'EXPENSE',
    amount: 9_900,
    accountId: cash,
    categoryId: food,
    date: '2026-09-30T18:00:00Z',
  })
  await post('/api/v1/transactions', {
    type: 'EXPENSE',
    amount: 125_050,
    accountId: cash,
    categoryId: snacks,
    note: 'Party, "big" one\nsecond line',
    date: '2026-10-01T04:30:00Z', // 10:00 IST
  })
  await post('/api/v1/transactions', {
    type: 'TRANSFER',
    amount: 20_000,
    accountId: cash,
    toAccountId: bank,
    note: '=HYPERLINK("x")',
    date: '2026-10-02T12:00:00Z',
  })
  await post('/api/v1/transactions', {
    type: 'LEND',
    amount: 5_000,
    accountId: cash,
    personId: amit,
    dueDate: '2026-10-20',
    date: '2026-10-02T13:00:00Z',
  })
  return { token, cash, bank, food, snacks, amit }
}

/** CSV text → rows of cells (handles quotes and newlines inside quotes). */
function parseCsv(text: string) {
  const rows: string[][] = []
  let row: string[] = []
  let value = ''
  let quoted = false
  for (let i = 0; i < text.length; i++) {
    const ch = text[i]
    if (quoted) {
      if (ch === '"' && text[i + 1] === '"') {
        value += '"'
        i++
      } else if (ch === '"') {
        quoted = false
      } else {
        value += ch
      }
    } else if (ch === '"') {
      quoted = true
    } else if (ch === ',') {
      row.push(value)
      value = ''
    } else if (ch === '\r') {
      continue
    } else if (ch === '\n') {
      row.push(value)
      rows.push(row)
      row = []
      value = ''
    } else {
      value += ch
    }
  }
  return rows
}

async function csv(client: ApiClient, token: string, query = '') {
  const response = await client.get(`/api/v1/export/transactions.csv${query}`).bearerToken(token)
  response.assertStatus(200)
  return response
}

test.group('export', (group) => {
  group.each.setup(() => testUtils.db().withGlobalTransaction())

  test('transactions CSV: local dates, names, rupees, oldest first', async ({ client, assert }) => {
    const ids = await setup(client)
    const response = await csv(client, ids.token)
    assert.match(response.header('content-type') ?? '', /^text\/csv/)
    assert.include(response.header('content-disposition'), 'hisaabchat-transactions-all.csv')
    const text = response.text()
    assert.isTrue(text.startsWith('﻿'), 'starts with a BOM for Excel')

    const [header, ...rows] = parseCsv(text.slice(1))
    assert.deepEqual(header, [
      'Date',
      'Time',
      'Type',
      'Amount',
      'Signed amount',
      'Account',
      'To account',
      'Category',
      'Person',
      'Note',
      'Due date',
      'Recurring',
      'Id',
    ])
    assert.lengthOf(rows, 4)
    assert.deepEqual(rows[0].slice(0, 8), [
      '2026-09-30',
      '23:30',
      'Expense',
      '99.00',
      '-99.00',
      'Cash',
      '',
      'Food & Groceries',
    ])
    assert.deepEqual(rows[1].slice(0, 10), [
      '2026-10-01',
      '10:00',
      'Expense',
      '1250.50',
      '-1250.50',
      'Cash',
      '',
      'Food & Groceries / Snacks',
      '',
      'Party, "big" one\nsecond line',
    ])
    // A note that looks like a formula is defused; transfers net to zero.
    assert.deepEqual(rows[2].slice(2, 10), [
      'Transfer',
      '200.00',
      '0.00',
      'Cash',
      'Bank, SBI',
      '',
      '',
      `'=HYPERLINK("x")`,
    ])
    assert.deepEqual(rows[3].slice(2, 11), [
      'Lent',
      '50.00',
      '-50.00',
      'Cash',
      '',
      '',
      'Amit',
      '',
      '2026-10-20',
    ])
  })

  test('transactions CSV: date range in the user’s time zone, and account/person filters', async ({
    client,
    assert,
  }) => {
    const ids = await setup(client)

    const october = await csv(client, ids.token, '?from=2026-10-01&to=2026-10-31')
    assert.include(
      october.header('content-disposition'),
      'hisaabchat-transactions-2026-10-01-to-2026-10-31.csv'
    )
    assert.lengthOf(parseCsv(october.text().slice(1)), 4) // header + 3

    const firstOnly = await csv(client, ids.token, '?from=2026-10-01&to=2026-10-01')
    assert.lengthOf(parseCsv(firstOnly.text().slice(1)), 2)

    const bank = await csv(client, ids.token, `?accountId=${ids.bank}`)
    const bankRows = parseCsv(bank.text().slice(1)).slice(1)
    assert.deepEqual(
      bankRows.map((r) => r[2]),
      ['Transfer']
    )

    const amit = await csv(client, ids.token, `?personId=${ids.amit}`)
    assert.deepEqual(
      parseCsv(amit.text().slice(1))
        .slice(1)
        .map((r) => r[2]),
      ['Lent']
    )

    const bad = await client
      .get('/api/v1/export/transactions.csv?from=2026-13-01')
      .bearerToken(ids.token)
    bad.assertStatus(422)
  })

  test('only your own transactions, and only when signed in', async ({ client, assert }) => {
    await setup(client)
    const { token } = await registerUser(client, 'Someone else')
    const response = await csv(client, token)
    assert.lengthOf(parseCsv(response.text().slice(1)), 1) // just the header

    const anonymous = await client.get('/api/v1/export/transactions.csv')
    anonymous.assertStatus(401)
    const anonymousJson = await client.get('/api/v1/export/all.json')
    anonymousJson.assertStatus(401)
  })

  test('all.json has everything, with ids that link up', async ({ client, assert }) => {
    const ids = await setup(client)
    await client
      .post('/api/v1/budgets')
      .bearerToken(ids.token)
      .json({ name: 'Food', amount: 300_000, categoryIds: [ids.food] })
      .then((r) => r.assertStatus(201))
    await client
      .post('/api/v1/recurring')
      .bearerToken(ids.token)
      .json({
        type: 'EXPENSE',
        amount: 1_000,
        accountId: ids.cash,
        categoryId: ids.food,
        frequency: 'MONTHLY',
        startDate: '2026-11-01',
      })
      .then((r) => r.assertStatus(201))

    const response = await client.get('/api/v1/export/all.json').bearerToken(ids.token)
    response.assertStatus(200)
    assert.match(
      response.header('content-disposition') ?? '',
      /hisaabchat-backup-\d{4}-\d{2}-\d{2}\.json/
    )
    const body = json(response)

    assert.equal(body.app, 'HisaabChat')
    assert.equal(body.amountsIn, 'paise')
    assert.equal(body.user.fullName, 'Asha')
    assert.notProperty(body.user, 'password')
    assert.notProperty(body.user, 'id')

    assert.deepEqual(
      body.accounts.map((a: any) => [a.name, a.balance]),
      [
        ['Cash', 100_000 - 9_900 - 125_050 - 20_000 - 5_000],
        ['Bank, SBI', 20_000],
      ]
    )
    assert.lengthOf(body.transactions, 4)
    const transfer = body.transactions.find((t: any) => t.type === 'TRANSFER')
    assert.equal(transfer.accountId, ids.cash)
    assert.equal(transfer.toAccountId, ids.bank)
    assert.equal(body.transactions[3].dueDate, '2026-10-20')
    assert.equal(body.transactions[3].personId, ids.amit)

    const snacks = body.categories.find((c: any) => c.id === ids.snacks)
    assert.equal(snacks.parentId, ids.food)
    assert.equal(body.budgets[0].name, 'Food')
    assert.equal(body.categories.find((c: any) => c.id === ids.food).budgetId, body.budgets[0].id)
    assert.deepEqual(body.budgets[0].overrides, [])
    assert.deepEqual(
      body.people.map((p: any) => p.name),
      ['Amit']
    )
    assert.equal(body.recurringRules[0].startDate, '2026-11-01')
    assert.isTrue(body.recurringRules[0].isActive)
  })
})

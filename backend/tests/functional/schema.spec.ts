import { test } from '@japa/runner'
import testUtils from '@adonisjs/core/services/test_utils'
import { v7 as uuidv7 } from 'uuid'
import { DateTime } from 'luxon'
import User from '#models/user'
import Account from '#models/account'
import Category from '#models/category'
import Transaction from '#models/transaction'

/**
 * Verifies the database itself enforces the rules from docs/05-Backend-Schema.md,
 * independently of the service layer.
 */
test.group('database schema', (group) => {
  group.each.setup(() => testUtils.db().withGlobalTransaction())

  async function seed() {
    const user = await User.create({
      email: `${uuidv7()}@example.com`,
      password: 'secret-password',
    })
    const cash = await Account.create({
      userId: user.id,
      name: 'Cash',
      type: 'CASH',
      openingBalance: 230_000,
      balance: 230_000,
    })
    const bank = await Account.create({ userId: user.id, name: 'SBI', type: 'BANK' })
    const petrol = await Category.create({
      userId: user.id,
      name: 'Petrol',
      type: 'EXPENSE',
      color: '#F59E0B',
      icon: 'local_gas_station',
    })
    return { user, cash, bank, petrol }
  }

  test('models get UUID v7 ids and money/boolean columns round-trip', async ({ assert }) => {
    const { user, cash } = await seed()

    assert.match(user.id, /^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-/)
    const fresh = await Account.findOrFail(cash.id)
    assert.strictEqual(fresh.balance, 230_000)
    assert.strictEqual(fresh.includeInTotal, true)
    assert.equal(fresh.type, 'CASH')
  })

  test('accepts a well-formed expense with a client-supplied id', async ({ assert }) => {
    const { user, cash, petrol } = await seed()
    const id = uuidv7()

    const txn = await Transaction.create({
      id,
      userId: user.id,
      type: 'EXPENSE',
      amount: 12_000,
      date: DateTime.utc(),
      accountId: cash.id,
      categoryId: petrol.id,
    })
    assert.equal(txn.id, id)
  })

  test('rejects a non-positive amount', async ({ assert }) => {
    const { user, cash, petrol } = await seed()

    await assert.rejects(() =>
      Transaction.create({
        userId: user.id,
        type: 'EXPENSE',
        amount: 0,
        date: DateTime.utc(),
        accountId: cash.id,
        categoryId: petrol.id,
      })
    )
  })

  test('rejects an expense without a category', async ({ assert }) => {
    const { user, cash } = await seed()

    await assert.rejects(() =>
      Transaction.create({
        userId: user.id,
        type: 'EXPENSE',
        amount: 500,
        date: DateTime.utc(),
        accountId: cash.id,
      })
    )
  })

  test('rejects a transfer to the same account', async ({ assert }) => {
    const { user, cash } = await seed()

    await assert.rejects(() =>
      Transaction.create({
        userId: user.id,
        type: 'TRANSFER',
        amount: 500,
        date: DateTime.utc(),
        accountId: cash.id,
        toAccountId: cash.id,
      })
    )
  })

  test('accepts a transfer between two accounts', async ({ assert }) => {
    const { user, cash, bank } = await seed()

    const txn = await Transaction.create({
      userId: user.id,
      type: 'TRANSFER',
      amount: 200_000,
      date: DateTime.utc(),
      accountId: bank.id,
      toAccountId: cash.id,
    })
    assert.equal(txn.type, 'TRANSFER')
  })
})

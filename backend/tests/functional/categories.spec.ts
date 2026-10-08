import { test } from '@japa/runner'
import testUtils from '@adonisjs/core/services/test_utils'
import { json, registerUser } from '#tests/helpers'

test.group('categories', (group) => {
  group.each.setup(() => testUtils.db().withGlobalTransaction())

  test('lists defaults, expense first', async ({ client, assert }) => {
    const { token } = await registerUser(client)
    const list = json(await client.get('/api/v1/categories').bearerToken(token)).data
    assert.lengthOf(list, 22)
    assert.equal(list[0].type, 'EXPENSE')
    assert.equal(list[0].name, 'Room Rent')
    assert.equal(list.at(-1).type, 'INCOME')

    const income = json(await client.get('/api/v1/categories?type=INCOME').bearerToken(token)).data
    assert.lengthOf(income, 6)
  })

  test('create, rename, archive and restore', async ({ client, assert }) => {
    const { token } = await registerUser(client)
    const created = await client
      .post('/api/v1/categories')
      .bearerToken(token)
      .json({ name: 'Pets', type: 'EXPENSE', color: '#F97316', icon: 'pets' })
    created.assertStatus(201)
    const id = json(created).data.id

    const renamed = await client
      .patch(`/api/v1/categories/${id}`)
      .bearerToken(token)
      .json({ name: 'Pet care', color: '#14B8A6' })
    renamed.assertBodyContains({ data: { name: 'Pet care', color: '#14B8A6', type: 'EXPENSE' } })

    await client.post(`/api/v1/categories/${id}/archive`).bearerToken(token)
    const active = json(await client.get('/api/v1/categories').bearerToken(token)).data
    assert.notInclude(
      active.map((c: { id: string }) => c.id),
      id
    )
    const all = json(
      await client.get('/api/v1/categories?includeArchived=true').bearerToken(token)
    ).data
    assert.isTrue(all.find((c: { id: string }) => c.id === id).archived)

    const restored = await client.post(`/api/v1/categories/${id}/unarchive`).bearerToken(token)
    restored.assertBodyContains({ data: { archived: false } })
  })

  test('names are unique per type', async ({ client }) => {
    const { token } = await registerUser(client)
    const duplicate = await client
      .post('/api/v1/categories')
      .bearerToken(token)
      .json({ name: 'petrol', type: 'EXPENSE', color: '#F97316', icon: 'pets' })
    duplicate.assertStatus(422)
    duplicate.assertBodyContains({ errors: [{ field: 'name', rule: 'unique' }] })

    // Same name is fine for the other type.
    const otherType = await client
      .post('/api/v1/categories')
      .bearerToken(token)
      .json({ name: 'Petrol', type: 'INCOME', color: '#F97316', icon: 'pets' })
    otherType.assertStatus(201)
  })

  test('reorder saves the new order', async ({ client, assert }) => {
    const { token } = await registerUser(client)
    const income = json(await client.get('/api/v1/categories?type=INCOME').bearerToken(token)).data
    const reversed = income.map((c: { id: string }) => c.id).reverse()

    await client.put('/api/v1/categories/order').bearerToken(token).json({ ids: reversed })
    const after = json(await client.get('/api/v1/categories?type=INCOME').bearerToken(token)).data
    assert.deepEqual(
      after.map((c: { id: string }) => c.id),
      reversed
    )
  })

  test("another user's category is not found", async ({ client }) => {
    const owner = await registerUser(client)
    const other = await registerUser(client)
    const id = json(await client.get('/api/v1/categories').bearerToken(owner.token)).data[0].id

    const response = await client
      .patch(`/api/v1/categories/${id}`)
      .bearerToken(other.token)
      .json({ name: 'Mine' })
    response.assertStatus(404)
  })
})

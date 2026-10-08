import { test } from '@japa/runner'
import testUtils from '@adonisjs/core/services/test_utils'
import db from '@adonisjs/lucid/services/db'
import type { ApiClient } from '@japa/api-client'
import { DEFAULT_CATEGORIES } from '#services/user_defaults_service'

const credentials = {
  fullName: 'Musaraf Hossain',
  email: 'test.user@example.com',
  password: 'secret-password',
  passwordConfirmation: 'secret-password',
}

test.group('auth / register', (group) => {
  group.each.setup(() => testUtils.db().withGlobalTransaction())

  test('creates the user with defaults and returns a token', async ({ client, assert }) => {
    const response = await client
      .post('/api/v1/auth/register')
      .json({ ...credentials, deviceName: 'Windows' })

    response.assertStatus(201)
    const { user, token } = response.body().data
    assert.match(user.id, /^[0-9a-f-]{36}$/)
    assert.equal(user.email, credentials.email)
    assert.equal(user.initials, 'MH')
    assert.equal(user.currency, 'INR')
    assert.equal(user.timezone, 'Asia/Kolkata')
    assert.equal(user.monthStartDay, 1)
    assert.equal(user.theme, 'SYSTEM')
    assert.isNull(user.onboardedAt)
    assert.notProperty(user, 'password')
    assert.match(token, /^oat_/)

    const tokenRow = await db
      .from('auth_access_tokens')
      .where('tokenable_id', user.id)
      .firstOrFail()
    assert.equal(tokenRow.name, 'Windows')
  })

  test('seeds the 22 default categories', async ({ client, assert }) => {
    const response = await client.post('/api/v1/auth/register').json(credentials)
    const userId = response.body().data.user.id

    const rows = await db.from('categories').where('user_id', userId).orderBy('sort_order')
    assert.lengthOf(rows, DEFAULT_CATEGORIES.length)
    assert.equal(rows.filter((row) => row.type === 'EXPENSE').length, 16)
    assert.equal(rows.filter((row) => row.type === 'INCOME').length, 6)
    assert.deepInclude(
      rows.map((row) => row.name),
      'Bike EMI'
    )
  })

  test('accepts the device time zone', async ({ client }) => {
    const response = await client
      .post('/api/v1/auth/register')
      .json({ ...credentials, timezone: 'Asia/Dubai' })
    response.assertStatus(201)
    response.assertBodyContains({ data: { user: { timezone: 'Asia/Dubai' } } })
  })

  test('rejects a duplicate email, mismatched confirmation and bad time zone', async ({
    client,
  }) => {
    await client.post('/api/v1/auth/register').json(credentials)

    const duplicate = await client.post('/api/v1/auth/register').json(credentials)
    duplicate.assertStatus(422)

    const mismatch = await client
      .post('/api/v1/auth/register')
      .json({ ...credentials, email: 'other@example.com', passwordConfirmation: 'different-pass' })
    mismatch.assertStatus(422)

    const badZone = await client
      .post('/api/v1/auth/register')
      .json({ ...credentials, email: 'zone@example.com', timezone: 'Mars/Base' })
    badZone.assertStatus(422)
    badZone.assertBodyContains({ errors: [{ field: 'timezone' }] })
  })
})

test.group('auth / login & logout', (group) => {
  group.each.setup(() => testUtils.db().withGlobalTransaction())

  test('logs in with email in any case', async ({ client }) => {
    await client.post('/api/v1/auth/register').json(credentials)

    const response = await client
      .post('/api/v1/auth/login')
      .json({ email: 'Test.User@Example.com', password: credentials.password })
    response.assertStatus(200)
    response.assertBodyContains({ data: { user: { email: credentials.email } } })
  })

  test('rejects a wrong password', async ({ client }) => {
    await client.post('/api/v1/auth/register').json(credentials)

    const response = await client
      .post('/api/v1/auth/login')
      .json({ email: credentials.email, password: 'wrong-password' })
    response.assertStatus(400)
  })

  async function twoSessions(client: ApiClient) {
    const register = await client.post('/api/v1/auth/register').json(credentials)
    const login = await client
      .post('/api/v1/auth/login')
      .json({ email: credentials.email, password: credentials.password })
    return [register.body().data.token as string, login.body().data.token as string]
  }

  async function meStatus(client: ApiClient, token?: string) {
    const request = client.get('/api/v1/me')
    const response = token ? await request.bearerToken(token) : await request
    return response.status()
  }

  test('logout revokes only the current token', async ({ client, assert }) => {
    const [first, second] = await twoSessions(client)

    const logout = await client.post('/api/v1/auth/logout').bearerToken(first)
    logout.assertStatus(200)
    assert.equal(await meStatus(client, first), 401)
    assert.equal(await meStatus(client, second), 200)
  })

  test('logout-all revokes every token', async ({ client, assert }) => {
    const [first, second] = await twoSessions(client)

    const response = await client.post('/api/v1/auth/logout-all').bearerToken(first)
    response.assertBodyContains({ data: { revoked: 2 } })
    assert.equal(await meStatus(client, first), 401)
    assert.equal(await meStatus(client, second), 401)
  })

  test('protected routes require a token', async ({ client, assert }) => {
    assert.equal(await meStatus(client), 401)
    const logout = await client.post('/api/v1/auth/logout')
    logout.assertStatus(401)
  })
})

import { test } from '@japa/runner'
import testUtils from '@adonisjs/core/services/test_utils'
import type { ApiClient } from '@japa/api-client'

async function registerAndGetToken(client: ApiClient) {
  const response = await client.post('/api/v1/auth/register').json({
    fullName: 'Asha Rao',
    email: 'asha@example.com',
    password: 'secret-password',
    passwordConfirmation: 'secret-password',
  })
  return response.body().data.token as string
}

test.group('me', (group) => {
  group.each.setup(() => testUtils.db().withGlobalTransaction())

  test('returns the profile', async ({ client }) => {
    const token = await registerAndGetToken(client)

    const response = await client.get('/api/v1/me').bearerToken(token)
    response.assertStatus(200)
    response.assertBodyContains({ data: { fullName: 'Asha Rao', currency: 'INR' } })
  })

  test('updates preferences', async ({ client }) => {
    const token = await registerAndGetToken(client)

    const response = await client.patch('/api/v1/me').bearerToken(token).json({
      fullName: 'Asha R.',
      currency: 'usd',
      timezone: 'Europe/London',
      monthStartDay: 25,
      theme: 'DARK',
    })

    response.assertStatus(200)
    response.assertBodyContains({
      data: {
        fullName: 'Asha R.',
        currency: 'USD',
        timezone: 'Europe/London',
        monthStartDay: 25,
        theme: 'DARK',
      },
    })
  })

  test('validates preferences', async ({ client, assert }) => {
    const token = await registerAndGetToken(client)

    for (const body of [
      { monthStartDay: 29 },
      { monthStartDay: 1.5 },
      { theme: 'NEON' },
      { currency: 'RUPEES' },
      { timezone: 'Nowhere/City' },
    ]) {
      const response = await client.patch('/api/v1/me').bearerToken(token).json(body)
      assert.equal(response.status(), 422, JSON.stringify(body))
    }

    // An empty name arrives as null (body parser) and is ignored, never saved.
    const blank = await client.patch('/api/v1/me').bearerToken(token).json({ fullName: '' })
    blank.assertBodyContains({ data: { fullName: 'Asha Rao' } })
  })

  test('completes onboarding once', async ({ client, assert }) => {
    const token = await registerAndGetToken(client)

    const first = await client.post('/api/v1/me/onboarding/complete').bearerToken(token)
    first.assertStatus(200)
    const onboardedAt = first.body().data.onboardedAt
    assert.isString(onboardedAt)

    const second = await client.post('/api/v1/me/onboarding/complete').bearerToken(token)
    assert.equal(
      Date.parse(String(second.body().data.onboardedAt)),
      Date.parse(String(onboardedAt))
    )
  })
})

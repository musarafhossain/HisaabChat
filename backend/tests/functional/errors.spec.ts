import { test } from '@japa/runner'
import { json, registerUser } from '#tests/helpers'

/**
 * Clients rely on one error shape: { errors: [{ message, code?, field? }] }.
 */
test.group('error responses', () => {
  test('unknown routes return a JSON error, not a stack trace', async ({ client, assert }) => {
    const response = await client.get('/api/v1/does-not-exist')
    response.assertStatus(404)
    assert.deepEqual(Object.keys(json(response)), ['errors'])
    assert.equal(json(response).errors[0].code, 'E_ROUTE_NOT_FOUND')
  })

  test('missing records return 404 with a message', async ({ client, assert }) => {
    const { token } = await registerUser(client)
    const response = await client
      .get('/api/v1/accounts/0192f1d2-7c1a-7b3e-9a1e-2f6c1d0a9b11')
      .bearerToken(token)
    response.assertStatus(404)
    assert.equal(json(response).errors[0].message, 'Account not found')
  })

  test('validation errors keep field details', async ({ client }) => {
    const { token } = await registerUser(client)
    const response = await client.post('/api/v1/accounts').bearerToken(token).json({ type: 'CASH' })
    response.assertStatus(422)
    response.assertBodyContains({ errors: [{ field: 'name' }] })
  })

  test('wrong credentials keep the auth error format', async ({ client }) => {
    const response = await client
      .post('/api/v1/auth/login')
      .json({ email: 'nobody@example.com', password: 'whatever-pass' })
    response.assertStatus(400)
    response.assertBodyContains({ errors: [{ message: 'Invalid user credentials' }] })
  })
})

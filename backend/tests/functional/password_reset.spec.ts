import { test } from '@japa/runner'
import testUtils from '@adonisjs/core/services/test_utils'
import type { ApiClient } from '@japa/api-client'
import mail from '@adonisjs/mail/services/main'
import db from '@adonisjs/lucid/services/db'
import { v7 as uuidv7 } from 'uuid'
import PasswordResetCode from '#mails/password_reset_code'
import { json } from '#tests/helpers'

const OLD = 'secret-password'
const NEW = 'brand-new-password'

async function register(client: ApiClient) {
  const email = `user.${uuidv7()}@example.com`
  const response = await client.post('/api/v1/auth/register').json({
    fullName: 'Asha',
    email,
    password: OLD,
    passwordConfirmation: OLD,
  })
  response.assertStatus(201)
  return { email, token: json(response).data.token as string }
}

/** The codes emailed so far (newest last). */
function codesSent(mails: ReturnType<typeof mail.fake>['mails']) {
  return mails.sent().map((m) => (m as PasswordResetCode).code)
}

const reset = (client: ApiClient, email: string, code: string, password = NEW) =>
  client.post('/api/v1/auth/reset-password').json({
    email,
    code,
    password,
    passwordConfirmation: password,
  })

const login = (client: ApiClient, email: string, password: string) =>
  client.post('/api/v1/auth/login').json({ email, password })

test.group('password reset', (group) => {
  group.each.setup(() => testUtils.db().withGlobalTransaction())
  group.each.teardown(() => mail.restore())

  test('emails a 6-digit code; the code sets a new password and signs out everywhere', async ({
    client,
    assert,
  }) => {
    const { mails } = mail.fake()
    const me = await register(client)

    const asked = await client.post('/api/v1/auth/forgot-password').json({ email: me.email })
    asked.assertStatus(200)
    asked.assertBodyContains({ data: { minutes: 15 } })
    mails.assertSent(PasswordResetCode, (m) => m.code.length === 6)
    const [code] = codesSent(mails)
    assert.match(code, /^\d{6}$/)
    const message = mails.sent()[0] as PasswordResetCode
    await message.build()
    assert.equal(message.message.toJSON().message.subject, `${code} is your HisaabChat code`)
    assert.deepEqual(message.message.toJSON().message.to, [me.email])
    assert.include(message.message.toJSON().message.text as string, code)

    // Only a hash is stored.
    const stored = await db.from('password_reset_tokens').select('token_hash').first()
    assert.notInclude(stored.token_hash, code)

    const wrong = await reset(client, me.email, code === '000000' ? '111111' : '000000')
    wrong.assertStatus(422)
    wrong.assertBodyContains({ errors: [{ field: 'code' }] })

    const ok = await reset(client, me.email, code)
    ok.assertStatus(200)

    // Old sessions are gone, the old password no longer works, the new one does.
    const meAfter = await client.get('/api/v1/me').bearerToken(me.token)
    meAfter.assertStatus(401)
    const oldLogin = await login(client, me.email, OLD)
    oldLogin.assertStatus(400)
    const newLogin = await login(client, me.email, NEW)
    newLogin.assertStatus(200)

    // A code works once.
    const again = await reset(client, me.email, code, 'another-password')
    again.assertStatus(422)
  })

  test('unknown emails get the same answer and no email', async ({ client }) => {
    const { mails } = mail.fake()
    const response = await client
      .post('/api/v1/auth/forgot-password')
      .json({ email: 'nobody@example.com' })
    response.assertStatus(200)
    response.assertBodyContains({ data: { minutes: 15 } })
    mails.assertNoneSent()

    const resetUnknown = await reset(client, 'nobody@example.com', '123456')
    resetUnknown.assertStatus(422)
    resetUnknown.assertBodyContains({ errors: [{ field: 'code' }] })
  })

  test('a new code replaces the old one, and codes expire', async ({ client, assert }) => {
    const { mails } = mail.fake()
    const me = await register(client)

    await client.post('/api/v1/auth/forgot-password').json({ email: me.email })
    await client.post('/api/v1/auth/forgot-password').json({ email: me.email })
    const [first, second] = codesSent(mails)
    assert.exists(second)

    if (first !== second) {
      const stale = await reset(client, me.email, first)
      stale.assertStatus(422)
    }

    // Expire the current code.
    await db.from('password_reset_tokens').update({ expires_at: new Date(Date.now() - 1000) })
    const expired = await reset(client, me.email, second)
    expired.assertStatus(422)
  })

  test('checks the code format and the new password', async ({ client }) => {
    mail.fake()
    const me = await register(client)

    const shortCode = await reset(client, me.email, '12345')
    shortCode.assertStatus(422)
    shortCode.assertBodyContains({ errors: [{ field: 'code' }] })

    const weak = await reset(client, me.email, '123456', 'short')
    weak.assertStatus(422)
    weak.assertBodyContains({ errors: [{ field: 'password' }] })

    const mismatch = await client.post('/api/v1/auth/reset-password').json({
      email: me.email,
      code: '123456',
      password: NEW,
      passwordConfirmation: 'something-else',
    })
    mismatch.assertStatus(422)
  })
})

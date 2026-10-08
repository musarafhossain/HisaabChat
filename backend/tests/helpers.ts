import type { ApiClient } from '@japa/api-client'
import { v7 as uuidv7 } from 'uuid'

/**
 * Registers a fresh user through the API and returns their id and token.
 */
export async function registerUser(client: ApiClient, fullName = 'Test User') {
  const response = await client.post('/api/v1/auth/register').json({
    fullName,
    email: `user.${uuidv7()}@example.com`,
    password: 'secret-password',
    passwordConfirmation: 'secret-password',
  })
  response.assertStatus(201)
  const { user, token } = response.body().data
  return { userId: user.id as string, token: token as string }
}

/**
 * Response body as plain JSON. The typed client can't infer bodies for URLs
 * built from template strings, so tests read them loosely.
 */

export const json = (response: { body(): unknown }) => response.body() as any

import { test } from '@japa/runner'

test.group('GET /api/v1/health', () => {
  test('reports the API and database as up', async ({ client }) => {
    const response = await client.get('/api/v1/health')

    response.assertStatus(200)
    response.assertBodyContains({ data: { status: 'ok', database: 'up' } })
  })
})

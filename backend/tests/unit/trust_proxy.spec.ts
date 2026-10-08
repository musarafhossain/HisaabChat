import { test } from '@japa/runner'
import { http } from '#config/app'

/**
 * Behind nginx on the same machine every request arrives from 127.0.0.1;
 * only that hop may set X-Forwarded-For (per-visitor login rate limits).
 */
test.group('trust proxy', () => {
  test('trusts the local reverse proxy only', ({ assert }) => {
    const trust = http.trustProxy as (address: string, hop: number) => boolean
    assert.isTrue(trust('127.0.0.1', 0))
    assert.isTrue(trust('::1', 0))
    assert.isFalse(trust('203.0.113.7', 0))
    assert.isFalse(trust('10.0.0.5', 0))
  })
})

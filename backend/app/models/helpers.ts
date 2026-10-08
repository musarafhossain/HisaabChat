import { v7 as uuidv7 } from 'uuid'

/**
 * Assigns a time-ordered UUID v7 primary key unless the client already
 * supplied one (transactions are created with client-generated ids so
 * retried requests stay idempotent).
 */
export function assignUuid(model: { id: string }) {
  model.id ??= uuidv7()
}

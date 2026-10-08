import vine from '@vinejs/vine'
import { DateTime } from 'luxon'

const name = () => vine.string().trim().minLength(1).maxLength(60)
const phone = () => vine.string().trim().maxLength(20).nullable()
const note = () => vine.string().trim().maxLength(200).nullable()
const color = () => vine.string().regex(/^#[0-9A-Fa-f]{6}$/)

const isoDateRule = vine.createRule((value, _, field) => {
  if (typeof value !== 'string' || !DateTime.fromISO(value, { setZone: true }).isValid) {
    field.report('The {{ field }} field must be an ISO-8601 date-time', 'isoDate', field)
  }
})

export const createPersonValidator = vine.create({
  name: name(),
  phone: phone().optional(),
  note: note().optional(),
  color: color().optional(),
})

export const updatePersonValidator = vine.create({
  name: name().optional(),
  phone: phone().optional(),
  note: note().optional(),
  color: color().optional(),
})

export const listPeopleValidator = vine.create({
  includeArchived: vine.boolean().optional(),
})

export const settlePersonValidator = vine.create({
  /** Client-generated transaction id (idempotent retries). */
  id: vine.string().uuid().optional(),
  accountId: vine.string().uuid(),
  amount: vine.number().withoutDecimals().min(1).optional(),
  date: vine
    .string()
    .use(isoDateRule())
    .transform((value) => DateTime.fromISO(value, { setZone: true }).toUTC().startOf('second'))
    .optional(),
  note: note().optional(),
})

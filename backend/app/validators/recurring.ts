import vine from '@vinejs/vine'
import { DateTime } from 'luxon'

const MAX_PAISE = 1_000_000_000_000_00

const validDate = vine.createRule((value, _, field) => {
  if (typeof value !== 'string' || !DateTime.fromISO(value, { setZone: true }).isValid) {
    field.report('The {{ field }} field must be a valid date', 'date', field)
  }
})

/** A calendar date ("2026-10-31"), kept as UTC midnight. */
const localDate = () =>
  vine
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .use(validDate())
    .transform((value) => DateTime.fromISO(value, { zone: 'utc' }))

/** An ISO-8601 instant with an offset, normalized to UTC. */
const instant = () =>
  vine
    .string()
    .use(validDate())
    .transform((value) => DateTime.fromISO(value, { setZone: true }).toUTC().startOf('second'))

const amount = () => vine.number().withoutDecimals().range([1, MAX_PAISE])
const note = () => vine.string().trim().maxLength(200).nullable()
const frequency = () => vine.enum(['DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY'] as const)

export const createRuleValidator = vine.create({
  type: vine.enum(['INCOME', 'EXPENSE', 'TRANSFER'] as const),
  amount: amount(),
  accountId: vine.string().uuid(),
  toAccountId: vine.string().uuid().nullable().optional(),
  categoryId: vine.string().uuid().nullable().optional(),
  note: note().optional(),
  frequency: frequency(),
  interval: vine.number().withoutDecimals().range([1, 365]).optional(),
  dayOfMonth: vine.number().withoutDecimals().range([1, 31]).nullable().optional(),
  startDate: localDate(),
  endDate: localDate().nullable().optional(),
  autoCreate: vine.boolean().optional(),
  linkTransactionId: vine.string().uuid().nullable().optional(),
})

export const updateRuleValidator = vine.create({
  type: vine.enum(['INCOME', 'EXPENSE', 'TRANSFER'] as const).optional(),
  amount: amount().optional(),
  accountId: vine.string().uuid().optional(),
  toAccountId: vine.string().uuid().nullable().optional(),
  categoryId: vine.string().uuid().nullable().optional(),
  note: note().optional(),
  frequency: frequency().optional(),
  interval: vine.number().withoutDecimals().range([1, 365]).optional(),
  dayOfMonth: vine.number().withoutDecimals().range([1, 31]).nullable().optional(),
  startDate: localDate().optional(),
  endDate: localDate().nullable().optional(),
  autoCreate: vine.boolean().optional(),
  isActive: vine.boolean().optional(),
})

export const upcomingValidator = vine.create({
  days: vine.number().withoutDecimals().range([1, 60]).optional(),
})

export const confirmOccurrenceValidator = vine.create({
  /** Client-generated transaction id (idempotent retries). */
  id: vine.string().uuid().optional(),
  amount: amount().optional(),
  accountId: vine.string().uuid().optional(),
  categoryId: vine.string().uuid().nullable().optional(),
  date: instant().optional(),
  note: note().optional(),
})

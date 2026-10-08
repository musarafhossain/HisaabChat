import vine from '@vinejs/vine'
import { DateTime } from 'luxon'

const MAX_PAISE = 1_000_000_000_000_00 // ₹1 lakh crore

/**
 * ISO-8601 timestamp with an offset ("2026-10-08T19:45:00+05:30"),
 * normalized to UTC.
 */
const isoDateRule = vine.createRule((value, _, field) => {
  if (typeof value !== 'string' || !DateTime.fromISO(value, { setZone: true }).isValid) {
    field.report('The {{ field }} field must be an ISO-8601 date-time', 'isoDate', field)
  }
})
const isoDate = () =>
  vine
    .string()
    .use(isoDateRule())
    .transform((value) => DateTime.fromISO(value, { setZone: true }).toUTC().startOf('second'))

/** A calendar date ("2026-10-31"), kept as UTC midnight. */
const localDate = () =>
  vine
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .use(isoDateRule())
    .transform((value) => DateTime.fromISO(value, { zone: 'utc' }))

const TYPES = ['INCOME', 'EXPENSE', 'TRANSFER', 'LEND', 'BORROW', 'COLLECT', 'REPAY'] as const

const amount = () => vine.number().withoutDecimals().range([1, MAX_PAISE])
const note = () => vine.string().trim().maxLength(200).nullable()

export const createTransactionValidator = vine.create({
  /** Client-generated id makes retries idempotent. */
  id: vine.string().uuid().optional(),
  type: vine.enum(TYPES),
  amount: amount(),
  accountId: vine.string().uuid(),
  toAccountId: vine.string().uuid().nullable().optional(),
  categoryId: vine.string().uuid().nullable().optional(),
  personId: vine.string().uuid().nullable().optional(),
  dueDate: localDate().nullable().optional(),
  date: isoDate(),
  note: note().optional(),
})

export const updateTransactionValidator = vine.create({
  type: vine.enum(TYPES).optional(),
  amount: amount().optional(),
  accountId: vine.string().uuid().optional(),
  toAccountId: vine.string().uuid().nullable().optional(),
  categoryId: vine.string().uuid().nullable().optional(),
  personId: vine.string().uuid().nullable().optional(),
  dueDate: localDate().nullable().optional(),
  date: isoDate().optional(),
  note: note().optional(),
})

export const listTransactionsValidator = vine.create({
  from: isoDate().optional(),
  to: isoDate().optional(),
  type: vine.enum([...TYPES, 'ADJUSTMENT'] as const).optional(),
  accountId: vine.string().uuid().optional(),
  categoryId: vine.string().uuid().optional(),
  personId: vine.string().uuid().optional(),
  q: vine.string().trim().maxLength(100).optional(),
  cursor: vine.string().maxLength(200).optional(),
  limit: vine.number().withoutDecimals().range([1, 100]).optional(),
})

export const reconcileValidator = vine.create({
  actualBalance: vine.number().withoutDecimals().range([-MAX_PAISE, MAX_PAISE]),
})

import vine from '@vinejs/vine'

export const ACCOUNT_TYPES = ['CASH', 'BANK', 'WALLET', 'CREDIT_CARD', 'SAVINGS', 'OTHER'] as const

/**
 * Money in paise. Opening balances may be negative (credit card outstanding,
 * overdraft); limits are bounded well inside JS safe integers.
 */
const MAX_PAISE = 1_000_000_000_000_00 // ₹1 lakh crore
const paise = () => vine.number().withoutDecimals().range([-MAX_PAISE, MAX_PAISE])

const name = () => vine.string().trim().minLength(1).maxLength(60)
const color = () => vine.string().regex(/^#[0-9A-Fa-f]{6}$/)
const icon = () => vine.string().regex(/^[a-z0-9_]{1,40}$/)

export const createAccountValidator = vine.create({
  name: name(),
  type: vine.enum(ACCOUNT_TYPES),
  openingBalance: paise().optional(),
  creditLimit: vine.number().withoutDecimals().range([0, MAX_PAISE]).nullable().optional(),
  color: color().optional(),
  icon: icon().optional(),
  includeInTotal: vine.boolean().optional(),
})

export const updateAccountValidator = vine.create({
  name: name().optional(),
  type: vine.enum(ACCOUNT_TYPES).optional(),
  openingBalance: paise().optional(),
  creditLimit: vine.number().withoutDecimals().range([0, MAX_PAISE]).nullable().optional(),
  color: color().optional(),
  icon: icon().optional(),
  includeInTotal: vine.boolean().optional(),
  sortOrder: vine.number().withoutDecimals().range([0, 10_000]).optional(),
})

export const listAccountsValidator = vine.create({
  includeArchived: vine.boolean().optional(),
})

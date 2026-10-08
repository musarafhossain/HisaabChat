import vine from '@vinejs/vine'
import { DateTime } from 'luxon'

/**
 * Shared rules for email and password.
 */
const email = () => vine.string().trim().toLowerCase().email().maxLength(254)
const password = () => vine.string().minLength(8).maxLength(64)

/**
 * Optional label for the access token, e.g. "Android", "Windows", "Web".
 */
const deviceName = () => vine.string().trim().maxLength(60).optional()

/**
 * IANA time zone such as "Asia/Kolkata".
 */
const timezoneRule = vine.createRule((value, _, field) => {
  if (typeof value !== 'string' || !DateTime.local().setZone(value).isValid) {
    field.report('The {{ field }} field must be a valid time zone', 'timezone', field)
  }
})

/**
 * Validator to use when performing self-signup
 */
export const registerValidator = vine.create({
  fullName: vine.string().trim().minLength(1).maxLength(100),
  email: email().unique({ table: 'users', column: 'email' }),
  password: password(),
  passwordConfirmation: password().sameAs('password'),
  timezone: vine.string().use(timezoneRule()).optional(),
  deviceName: deviceName(),
})

/**
 * Validator to use before validating user credentials during login
 */
export const loginValidator = vine.create({
  email: email(),
  password: vine.string(),
  deviceName: deviceName(),
})

/**
 * Profile & preferences (PATCH /me). Every field is optional.
 */
export const updateProfileValidator = vine.create({
  fullName: vine.string().trim().minLength(1).maxLength(100).optional(),
  currency: vine
    .string()
    .toUpperCase()
    .regex(/^[A-Z]{3}$/)
    .optional(),
  timezone: vine.string().use(timezoneRule()).optional(),
  monthStartDay: vine.number().withoutDecimals().range([1, 28]).optional(),
  theme: vine.enum(['SYSTEM', 'LIGHT', 'DARK'] as const).optional(),
})

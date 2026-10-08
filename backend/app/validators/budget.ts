import vine from '@vinejs/vine'

const MAX_PAISE = 1_000_000_000_000_00

const month = () => vine.string().regex(/^\d{4}-(0[1-9]|1[0-2])$/)

export const createBudgetValidator = vine.create({
  name: vine.string().trim().minLength(1).maxLength(40),
  amount: vine.number().withoutDecimals().range([0, MAX_PAISE]),
  kind: vine.enum(['FIXED', 'VARIABLE'] as const).optional(),
  alertPercent: vine.number().withoutDecimals().range([1, 100]).optional(),
  color: vine
    .string()
    .regex(/^#[0-9A-Fa-f]{6}$/)
    .optional(),
  icon: vine
    .string()
    .regex(/^[a-z0-9_]{1,40}$/)
    .optional(),
  categoryIds: vine.array(vine.string().uuid()).minLength(1).maxLength(50),
})

export const updateBudgetValidator = vine.create({
  name: vine.string().trim().minLength(1).maxLength(40).optional(),
  amount: vine.number().withoutDecimals().range([0, MAX_PAISE]).optional(),
  kind: vine.enum(['FIXED', 'VARIABLE'] as const).optional(),
  alertPercent: vine.number().withoutDecimals().range([1, 100]).optional(),
  color: vine
    .string()
    .regex(/^#[0-9A-Fa-f]{6}$/)
    .optional(),
  icon: vine
    .string()
    .regex(/^[a-z0-9_]{1,40}$/)
    .optional(),
  categoryIds: vine.array(vine.string().uuid()).minLength(1).maxLength(50).optional(),
  sortOrder: vine.number().withoutDecimals().range([0, 10_000]).optional(),
})

export const monthQueryValidator = vine.create({
  month: month().optional(),
})

export const overrideValidator = vine.create({
  amount: vine.number().withoutDecimals().range([0, MAX_PAISE]),
  params: vine.object({ month: month() }),
})

export const overrideParamsValidator = vine.create({
  params: vine.object({ month: month() }),
})

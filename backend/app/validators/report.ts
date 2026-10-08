import vine from '@vinejs/vine'

const month = () => vine.string().regex(/^\d{4}-(0[1-9]|1[0-2])$/)

export const dashboardValidator = vine.create({
  month: month().optional(),
})

export const byCategoryValidator = vine.create({
  month: month().optional(),
  type: vine.enum(['EXPENSE', 'INCOME'] as const).optional(),
})

export const trendValidator = vine.create({
  month: month().optional(),
  months: vine.number().withoutDecimals().range([1, 24]).optional(),
})

import vine from '@vinejs/vine'

const localDate = () => vine.string().regex(/^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$/)

export const exportCsvValidator = vine.create({
  from: localDate().optional(),
  to: localDate().optional(),
  accountId: vine.string().uuid().optional(),
  personId: vine.string().uuid().optional(),
})

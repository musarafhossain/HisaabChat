import vine from '@vinejs/vine'

const name = () => vine.string().trim().minLength(1).maxLength(40)
const color = () => vine.string().regex(/^#[0-9A-Fa-f]{6}$/)
const icon = () => vine.string().regex(/^[a-z0-9_]{1,40}$/)

export const createCategoryValidator = vine.create({
  name: name(),
  type: vine.enum(['INCOME', 'EXPENSE'] as const),
  color: color(),
  icon: icon(),
  parentId: vine.string().uuid().nullable().optional(),
})

export const updateCategoryValidator = vine.create({
  name: name().optional(),
  color: color().optional(),
  icon: icon().optional(),
})

export const listCategoriesValidator = vine.create({
  type: vine.enum(['INCOME', 'EXPENSE'] as const).optional(),
  includeArchived: vine.boolean().optional(),
})

export const reorderCategoriesValidator = vine.create({
  ids: vine.array(vine.string().uuid()).minLength(1).maxLength(500),
})

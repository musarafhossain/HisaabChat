import db from '@adonisjs/lucid/services/db'
import { Exception } from '@adonisjs/core/exceptions'
import { errors as vineErrors } from '@vinejs/vine'
import { DateTime } from 'luxon'
import Category, { type CategoryType } from '#models/category'
import type User from '#models/user'

const notFound = () => new Exception('Category not found', { status: 404, code: 'E_NOT_FOUND' })

export default class CategoryService {
  static async list(user: User, options: { type?: CategoryType; includeArchived?: boolean } = {}) {
    const query = Category.query()
      .where('userId', user.id)
      .orderBy('type', 'desc') // EXPENSE before INCOME
      .orderBy('sortOrder')
      .orderBy('name')
    if (options.type) query.where('type', options.type)
    if (!options.includeArchived) query.whereNull('archivedAt')
    return query
  }

  static async create(
    user: User,
    input: {
      name: string
      type: CategoryType
      color: string
      icon: string
      parentId?: string | null
    }
  ) {
    await this.assertNameAvailable(user, input.type, input.name)
    if (input.parentId) {
      const parent = await this.find(user, input.parentId)
      if (parent.type !== input.type || parent.parentId) {
        throw new vineErrors.E_VALIDATION_ERROR([
          {
            field: 'parentId',
            rule: 'invalid',
            message: 'Choose a top-level category of the same type',
          },
        ])
      }
    }
    const row = await Category.query().where('userId', user.id).max('sort_order as max').first()
    const max = row?.$extras.max as number | null | undefined
    return Category.create({
      userId: user.id,
      name: input.name,
      type: input.type,
      color: input.color,
      icon: input.icon,
      parentId: input.parentId ?? null,
      sortOrder: max === null || max === undefined ? 0 : max + 1,
    })
  }

  static async update(
    user: User,
    id: string,
    changes: { name?: string; color?: string; icon?: string }
  ) {
    const category = await this.find(user, id)
    if (changes.name !== undefined)
      await this.assertNameAvailable(user, category.type, changes.name, id)
    category.merge(changes)
    await category.save()
    return category
  }

  static async setArchived(user: User, id: string, archived: boolean) {
    const category = await this.find(user, id)
    category.archivedAt = archived ? DateTime.utc().startOf('second') : null
    await category.save()
    return category
  }

  /**
   * Saves a new display order. Ids not owned by the user are ignored.
   */
  static async reorder(user: User, ids: string[]) {
    await db.transaction(async (trx) => {
      for (const [index, id] of ids.entries()) {
        await trx
          .from('categories')
          .where('user_id', user.id)
          .where('id', id)
          .update({ sort_order: index })
      }
    })
    return this.list(user, { includeArchived: true })
  }

  static async find(user: User, id: string) {
    const category = await Category.query().where('userId', user.id).where('id', id).first()
    if (!category) throw notFound()
    return category
  }

  private static async assertNameAvailable(
    user: User,
    type: CategoryType,
    name: string,
    exceptId?: string
  ) {
    const query = Category.query().where('userId', user.id).where('type', type).where('name', name)
    if (exceptId) query.whereNot('id', exceptId)
    if (await query.first()) {
      throw new vineErrors.E_VALIDATION_ERROR([
        { field: 'name', rule: 'unique', message: 'You already have a category with this name' },
      ])
    }
  }
}

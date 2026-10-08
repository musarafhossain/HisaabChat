import type Category from '#models/category'
import { BaseTransformer } from '@adonisjs/core/transformers'

export default class CategoryTransformer extends BaseTransformer<Category> {
  toObject() {
    return this.pick(this.resource, [
      'id',
      'name',
      'type',
      'color',
      'icon',
      'parentId',
      'budgetId',
      'isDefault',
      'sortOrder',
      'archived',
    ])
  }
}

import type { HttpContext } from '@adonisjs/core/http'
import CategoryService from '#services/category_service'
import CategoryTransformer from '#transformers/category_transformer'
import {
  createCategoryValidator,
  listCategoriesValidator,
  reorderCategoriesValidator,
  updateCategoryValidator,
} from '#validators/category'

export default class CategoriesController {
  async index({ auth, request, serialize }: HttpContext) {
    const options = await request.validateUsing(listCategoriesValidator, { data: request.qs() })
    const categories = await CategoryService.list(auth.getUserOrFail(), options)
    return serialize(CategoryTransformer.transform(categories))
  }

  async store({ auth, request, response, serialize }: HttpContext) {
    const input = await request.validateUsing(createCategoryValidator)
    const category = await CategoryService.create(auth.getUserOrFail(), input)
    response.status(201)
    return serialize(CategoryTransformer.transform(category))
  }

  async update({ auth, params, request, serialize }: HttpContext) {
    const changes = await request.validateUsing(updateCategoryValidator)
    const category = await CategoryService.update(auth.getUserOrFail(), params.id, changes)
    return serialize(CategoryTransformer.transform(category))
  }

  async archive({ auth, params, serialize }: HttpContext) {
    const category = await CategoryService.setArchived(auth.getUserOrFail(), params.id, true)
    return serialize(CategoryTransformer.transform(category))
  }

  async unarchive({ auth, params, serialize }: HttpContext) {
    const category = await CategoryService.setArchived(auth.getUserOrFail(), params.id, false)
    return serialize(CategoryTransformer.transform(category))
  }

  async reorder({ auth, request, serialize }: HttpContext) {
    const { ids } = await request.validateUsing(reorderCategoriesValidator)
    const categories = await CategoryService.reorder(auth.getUserOrFail(), ids)
    return serialize(CategoryTransformer.transform(categories))
  }
}

import type Account from '#models/account'
import { BaseTransformer } from '@adonisjs/core/transformers'

export default class AccountTransformer extends BaseTransformer<Account> {
  toObject() {
    return this.pick(this.resource, [
      'id',
      'name',
      'type',
      'openingBalance',
      'balance',
      'creditLimit',
      'color',
      'icon',
      'includeInTotal',
      'sortOrder',
      'archived',
      'archivedAt',
      'createdAt',
      'updatedAt',
    ])
  }
}

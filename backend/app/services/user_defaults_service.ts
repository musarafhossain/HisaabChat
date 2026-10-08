import type { TransactionClientContract } from '@adonisjs/lucid/types/database'
import Category, { type CategoryType } from '#models/category'
import type User from '#models/user'

type DefaultCategory = { name: string; type: CategoryType; icon: string; color: string }

/**
 * Categories every new user starts with (docs/05-Backend-Schema.md §7).
 * Icon keys are Material Symbols names resolved by the Flutter AppIcons registry.
 */
export const DEFAULT_CATEGORIES: readonly DefaultCategory[] = [
  { type: 'EXPENSE', name: 'Room Rent', icon: 'home', color: '#4F46E5' },
  { type: 'EXPENSE', name: 'Food & Groceries', icon: 'shopping_cart', color: '#10B981' },
  { type: 'EXPENSE', name: 'Eating Out', icon: 'restaurant', color: '#F97316' },
  { type: 'EXPENSE', name: 'Bike EMI', icon: 'two_wheeler', color: '#8B5CF6' },
  { type: 'EXPENSE', name: 'Petrol', icon: 'local_gas_station', color: '#F59E0B' },
  { type: 'EXPENSE', name: 'Bike Maintenance', icon: 'build', color: '#64748B' },
  { type: 'EXPENSE', name: 'Education', icon: 'school', color: '#0EA5E9' },
  { type: 'EXPENSE', name: 'Utilities', icon: 'bolt', color: '#06B6D4' },
  { type: 'EXPENSE', name: 'Mobile & Internet', icon: 'wifi', color: '#14B8A6' },
  { type: 'EXPENSE', name: 'Shopping', icon: 'shopping_bag', color: '#EC4899' },
  { type: 'EXPENSE', name: 'Health', icon: 'medical_services', color: '#F43F5E' },
  { type: 'EXPENSE', name: 'Entertainment', icon: 'movie', color: '#84CC16' },
  { type: 'EXPENSE', name: 'Travel', icon: 'flight', color: '#0EA5E9' },
  { type: 'EXPENSE', name: 'Personal Care', icon: 'spa', color: '#EC4899' },
  { type: 'EXPENSE', name: 'Gifts', icon: 'redeem', color: '#F43F5E' },
  { type: 'EXPENSE', name: 'Other', icon: 'more_horiz', color: '#64748B' },
  { type: 'INCOME', name: 'Salary', icon: 'work', color: '#16A34A' },
  { type: 'INCOME', name: 'Freelance', icon: 'laptop_mac', color: '#14B8A6' },
  { type: 'INCOME', name: 'Pocket Money / Family', icon: 'family_restroom', color: '#4F46E5' },
  { type: 'INCOME', name: 'Interest', icon: 'percent', color: '#10B981' },
  { type: 'INCOME', name: 'Refund', icon: 'undo', color: '#06B6D4' },
  { type: 'INCOME', name: 'Other Income', icon: 'add_circle', color: '#64748B' },
]

export default class UserDefaultsService {
  /**
   * Seeds the default categories for a newly registered user. Runs inside
   * the registration transaction so a user never exists without them.
   */
  static async seed(user: User, trx: TransactionClientContract) {
    await Category.createMany(
      DEFAULT_CATEGORIES.map((category, index) => ({
        ...category,
        userId: user.id,
        isDefault: true,
        sortOrder: index,
      })),
      { client: trx }
    )
  }
}

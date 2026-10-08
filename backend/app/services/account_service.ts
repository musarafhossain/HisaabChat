import db from '@adonisjs/lucid/services/db'
import { errors as vineErrors } from '@vinejs/vine'
import { Exception } from '@adonisjs/core/exceptions'
import { DateTime } from 'luxon'
import Account, { type AccountType } from '#models/account'
import Transaction from '#models/transaction'
import type User from '#models/user'

/** Default icon and color per account type (docs/04-UI-UX-Design-Brief.md §2.4). */
export const ACCOUNT_TYPE_DEFAULTS: Record<AccountType, { icon: string; color: string }> = {
  CASH: { icon: 'payments', color: '#16A34A' },
  BANK: { icon: 'account_balance', color: '#4F46E5' },
  WALLET: { icon: 'smartphone', color: '#0EA5E9' },
  CREDIT_CARD: { icon: 'credit_card', color: '#F97316' },
  SAVINGS: { icon: 'savings', color: '#14B8A6' },
  OTHER: { icon: 'wallet', color: '#64748B' },
}

export type AccountInput = {
  name: string
  type: AccountType
  openingBalance?: number
  creditLimit?: number | null
  color?: string
  icon?: string
  includeInTotal?: boolean
}

export type AccountChanges = Partial<AccountInput> & { sortOrder?: number }

export default class AccountService {
  /**
   * Accounts for a user, ordered for display, plus their net worth:
   * the sum of active accounts that are included in the total.
   */
  static async list(user: User, options: { includeArchived?: boolean } = {}) {
    const query = Account.query().where('userId', user.id).orderBy('sortOrder').orderBy('createdAt')
    if (!options.includeArchived) query.whereNull('archivedAt')
    const accounts = await query

    const netWorth = accounts
      .filter((account) => !account.archived && account.includeInTotal)
      .reduce((sum, account) => sum + account.balance, 0)

    return { accounts, netWorth }
  }

  static async find(user: User, id: string) {
    const account = await Account.query().where('userId', user.id).where('id', id).first()
    if (!account) throw new Exception('Account not found', { status: 404, code: 'E_NOT_FOUND' })
    return account
  }

  static async create(user: User, input: AccountInput) {
    await this.assertNameAvailable(user, input.name)
    const defaults = ACCOUNT_TYPE_DEFAULTS[input.type]
    const openingBalance = input.openingBalance ?? 0
    const sortOrder = await this.nextSortOrder(user)

    return Account.create({
      userId: user.id,
      name: input.name,
      type: input.type,
      openingBalance,
      // No transactions yet, so the cached balance starts at the opening balance.
      balance: openingBalance,
      creditLimit: input.type === 'CREDIT_CARD' ? (input.creditLimit ?? null) : null,
      color: input.color ?? defaults.color,
      icon: input.icon ?? defaults.icon,
      includeInTotal: input.includeInTotal ?? true,
      sortOrder,
    })
  }

  /**
   * Updates an account. Changing the opening balance shifts the cached balance
   * by the same amount, inside a transaction with the row locked.
   */
  static async update(user: User, id: string, changes: AccountChanges) {
    if (changes.name !== undefined) await this.assertNameAvailable(user, changes.name, id)

    return db.transaction(async (trx) => {
      const account = await Account.query({ client: trx })
        .where('userId', user.id)
        .where('id', id)
        .forUpdate()
        .first()
      if (!account) throw new Exception('Account not found', { status: 404, code: 'E_NOT_FOUND' })

      const { openingBalance, ...rest } = changes
      account.merge(rest)
      if (openingBalance !== undefined && openingBalance !== account.openingBalance) {
        account.balance += openingBalance - account.openingBalance
        account.openingBalance = openingBalance
      }
      if (account.type !== 'CREDIT_CARD') account.creditLimit = null

      await account.useTransaction(trx).save()
      return account
    })
  }

  static async setArchived(user: User, id: string, archived: boolean) {
    const account = await this.find(user, id)
    account.archivedAt = archived ? DateTime.utc().startOf('second') : null
    await account.save()
    return account
  }

  /**
   * Hard delete is only allowed while nothing references the account;
   * otherwise the client should archive it instead.
   */
  static async delete(user: User, id: string) {
    const account = await this.find(user, id)
    const used = await Transaction.query()
      .where((query) => query.where('accountId', account.id).orWhere('toAccountId', account.id))
      .first()
    if (used) {
      throw new Exception('This account has transactions. Archive it instead.', {
        status: 409,
        code: 'E_ACCOUNT_IN_USE',
      })
    }
    await account.delete()
  }

  private static async assertNameAvailable(user: User, name: string, exceptId?: string) {
    const query = Account.query().where('userId', user.id).where('name', name)
    if (exceptId) query.whereNot('id', exceptId)
    if (await query.first()) {
      throw new vineErrors.E_VALIDATION_ERROR([
        { field: 'name', rule: 'unique', message: 'You already have an account with this name' },
      ])
    }
  }

  private static async nextSortOrder(user: User) {
    const row = await Account.query().where('userId', user.id).max('sort_order as max').first()
    const max = row?.$extras.max as number | null | undefined
    return max === null || max === undefined ? 0 : max + 1
  }
}

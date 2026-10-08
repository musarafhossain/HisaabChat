import type Account from '#models/account'
import type Category from '#models/category'
import type Transaction from '#models/transaction'
import { BaseTransformer } from '@adonisjs/core/transformers'

const accountRef = (account?: Account | null) =>
  account ? { id: account.id, name: account.name, icon: account.icon, color: account.color } : null

const categoryRef = (category?: Category | null) =>
  category
    ? {
        id: category.id,
        name: category.name,
        icon: category.icon,
        color: category.color,
        type: category.type,
      }
    : null

/**
 * TransactionDTO (docs/05-Backend-Schema.md §8). Expects account, toAccount
 * and category to be preloaded.
 */
export default class TransactionTransformer extends BaseTransformer<Transaction> {
  toObject() {
    const t = this.resource
    return {
      id: t.id,
      type: t.type,
      amount: t.amount,
      date: t.date.toUTC().toISO()!,
      note: t.note,
      adjustmentDirection: t.adjustmentDirection,
      account: accountRef(t.account)!,
      toAccount: accountRef(t.toAccount),
      category: categoryRef(t.category),
      isRecurring: t.recurringRuleId !== null,
      createdAt: t.createdAt.toUTC().toISO()!,
    }
  }
}

/**
 * Compact "last message" for an account tile: which way the money moved for
 * that account and a short label.
 */
export function lastTransactionPreview(accountId: string, t: Transaction) {
  const outgoing =
    (t.accountId === accountId && (t.type === 'EXPENSE' || t.type === 'TRANSFER')) ||
    (t.type === 'ADJUSTMENT' && t.adjustmentDirection === 'DECREASE')

  let label: string
  if (t.type === 'TRANSFER') {
    label = outgoing
      ? `To ${t.toAccount?.name ?? 'account'}`
      : `From ${t.account?.name ?? 'account'}`
  } else if (t.type === 'ADJUSTMENT') {
    label = 'Balance adjusted'
  } else {
    label = t.category?.name ?? (t.type === 'INCOME' ? 'Income' : 'Expense')
  }

  return {
    id: t.id,
    type: t.type,
    amount: t.amount,
    date: t.date.toUTC().toISO()!,
    direction: outgoing ? ('OUT' as const) : ('IN' as const),
    label,
    note: t.note,
  }
}

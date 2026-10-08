import db from '@adonisjs/lucid/services/db'
import type { TransactionClientContract } from '@adonisjs/lucid/types/database'
import type { AdjustmentDirection, TransactionType } from '#models/transaction'

export type Effect = { accountId: string; delta: number }

export type TxnLike = {
  type: TransactionType
  amount: number
  accountId: string
  toAccountId?: string | null
  adjustmentDirection?: AdjustmentDirection | null
}

/**
 * How a transaction moves account balances (docs/02-TRD.md §3.2).
 * Amounts are always positive; the direction comes from the type.
 */
export function effectsOf(t: TxnLike): Effect[] {
  switch (t.type) {
    case 'INCOME':
      return [{ accountId: t.accountId, delta: t.amount }]
    case 'EXPENSE':
      return [{ accountId: t.accountId, delta: -t.amount }]
    case 'TRANSFER':
      return [
        { accountId: t.accountId, delta: -t.amount },
        { accountId: t.toAccountId!, delta: t.amount },
      ]
    case 'ADJUSTMENT':
      return [
        {
          accountId: t.accountId,
          delta: t.adjustmentDirection === 'INCREASE' ? t.amount : -t.amount,
        },
      ]
    // Money leaves the account when you lend or pay back…
    case 'LEND':
    case 'REPAY':
      return [{ accountId: t.accountId, delta: -t.amount }]
    // …and comes in when you borrow or get paid back.
    case 'BORROW':
    case 'COLLECT':
      return [{ accountId: t.accountId, delta: t.amount }]
  }
}

export const negate = (effects: Effect[]): Effect[] =>
  effects.map((effect) => ({ ...effect, delta: -effect.delta }))

/**
 * Applies balance changes atomically (UPDATE … SET balance = balance + ?)
 * inside the caller's DB transaction.
 */
export async function applyEffects(trx: TransactionClientContract, effects: Effect[]) {
  for (const effect of effects) {
    if (effect.delta === 0) continue
    await trx.from('accounts').where('id', effect.accountId).increment('balance', effect.delta)
  }
}

export type BalanceDrift = { accountId: string; balance: number; computed: number }

/**
 * Accounts whose cached balance differs from opening balance + Σ effects.
 * Should always be empty; used by tests and the nightly balances check.
 */
export async function findBalanceDrift(userId?: string): Promise<BalanceDrift[]> {
  const result = await db.rawQuery(
    `
    SELECT a.id AS accountId, a.balance AS balance,
           a.opening_balance + COALESCE(SUM(e.delta), 0) AS computed
    FROM accounts a
    LEFT JOIN (
      SELECT account_id,
             CASE type
               WHEN 'INCOME' THEN amount
               WHEN 'EXPENSE' THEN -amount
               WHEN 'TRANSFER' THEN -amount
               WHEN 'ADJUSTMENT' THEN IF(adjustment_direction = 'INCREASE', amount, -amount)
               WHEN 'LEND' THEN -amount
               WHEN 'REPAY' THEN -amount
               WHEN 'BORROW' THEN amount
               WHEN 'COLLECT' THEN amount
             END AS delta
      FROM transactions
      UNION ALL
      SELECT to_account_id, amount FROM transactions WHERE type = 'TRANSFER'
    ) e ON e.account_id = a.id
    ${userId ? 'WHERE a.user_id = ?' : ''}
    GROUP BY a.id, a.balance, a.opening_balance
    HAVING a.balance <> computed
    `,
    userId ? [userId] : []
  )
  const rows = result[0] as Array<{ accountId: string; balance: number; computed: number }>
  return rows.map((row) => ({
    accountId: row.accountId,
    balance: Number(row.balance),
    computed: Number(row.computed),
  }))
}

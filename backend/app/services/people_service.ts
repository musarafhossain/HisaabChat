import db from '@adonisjs/lucid/services/db'
import { Exception } from '@adonisjs/core/exceptions'
import { errors as vineErrors } from '@vinejs/vine'
import { DateTime } from 'luxon'
import Person from '#models/person'
import type User from '#models/user'
import { formatMoney } from '#services/money'
import TransactionService from '#services/transaction_service'

const notFound = () => new Exception('Person not found', { status: 404, code: 'E_NOT_FOUND' })

const fieldError = (field: string, message: string, rule = 'invalid') =>
  new vineErrors.E_VALIDATION_ERROR([{ field, message, rule }])

/**
 * Positive = they owe you (you lent, or you paid back what you borrowed),
 * negative = you owe them. docs/05-Backend-Schema.md §3.1.
 */
const BALANCE_SQL = `COALESCE(SUM(CASE t.type
  WHEN 'LEND' THEN t.amount WHEN 'REPAY' THEN t.amount
  WHEN 'BORROW' THEN -t.amount WHEN 'COLLECT' THEN -t.amount END), 0)`

export type PersonInput = {
  name: string
  phone?: string | null
  note?: string | null
  color?: string
}

export type PersonEntry = { person: Person; balance: number; lastActivity: string | null }

export default class PeopleService {
  /**
   * People with their balances, most recent activity first, plus the totals
   * for Home's "You'll get / You owe" card.
   */
  static async list(user: User, options: { includeArchived?: boolean } = {}) {
    const people = await Person.query()
      .where('userId', user.id)
      .if(!options.includeArchived, (q) => q.whereNull('archivedAt'))
    const stats = await this.stats(user.id)
    const items: PersonEntry[] = people
      .map((person) => ({ person, ...this.statsFor(stats, person.id) }))
      .sort((a, b) => {
        const byActivity = (b.lastActivity ?? '').localeCompare(a.lastActivity ?? '')
        return byActivity === 0 ? a.person.name.localeCompare(b.person.name) : byActivity
      })
    const youGet = items.reduce((sum, i) => sum + Math.max(i.balance, 0), 0)
    const youOwe = items.reduce((sum, i) => sum + Math.max(-i.balance, 0), 0)
    return { items, youGet, youOwe }
  }

  static async find(user: User, id: string): Promise<PersonEntry> {
    const person = await Person.query().where('userId', user.id).where('id', id).first()
    if (!person) throw notFound()
    const stats = await this.stats(user.id, id)
    return { person, ...this.statsFor(stats, id) }
  }

  static async create(user: User, input: PersonInput): Promise<PersonEntry> {
    await this.assertNameAvailable(user, input.name)
    const person = await Person.create({
      userId: user.id,
      name: input.name,
      phone: input.phone ?? null,
      note: input.note ?? null,
      color: input.color ?? '#1DAA61',
    })
    return { person, balance: 0, lastActivity: null }
  }

  static async update(user: User, id: string, changes: Partial<PersonInput>) {
    const { person } = await this.find(user, id)
    if (changes.name !== undefined && changes.name !== person.name) {
      await this.assertNameAvailable(user, changes.name, id)
    }
    person.merge(changes)
    await person.save()
    return this.find(user, id)
  }

  /** Archiving hides a person; only allowed once you're square with them. */
  static async setArchived(user: User, id: string, archived: boolean) {
    const current = await this.find(user, id)
    if (archived && current.balance !== 0) {
      throw new Exception(`Settle up with ${current.person.name} before archiving`, {
        status: 422,
        code: 'E_NOT_SETTLED',
      })
    }
    current.person.archivedAt = archived ? DateTime.utc() : null
    await current.person.save()
    return this.find(user, id)
  }

  /**
   * Records the money that squares you up: a COLLECT when they owe you, a
   * REPAY when you owe them. `amount` defaults to the whole balance.
   */
  static async settle(
    user: User,
    id: string,
    input: {
      accountId: string
      amount?: number
      date?: DateTime
      id?: string
      note?: string | null
    }
  ) {
    const { person, balance } = await this.find(user, id)
    if (balance === 0) throw fieldError('amount', `You and ${person.name} are already settled`)
    const outstanding = Math.abs(balance)
    const amount = input.amount ?? outstanding
    if (amount > outstanding) {
      throw fieldError(
        'amount',
        `That's more than the ${formatMoney(outstanding)} outstanding`,
        'max'
      )
    }
    const { transaction } = await TransactionService.create(user, {
      id: input.id,
      type: balance > 0 ? 'COLLECT' : 'REPAY',
      amount,
      accountId: input.accountId,
      personId: person.id,
      date: input.date ?? DateTime.utc().startOf('second'),
      note: input.note ?? null,
    })
    return transaction
  }

  private static statsFor(stats: Map<string, Omit<PersonEntry, 'person'>>, id: string) {
    return stats.get(id) ?? { balance: 0, lastActivity: null }
  }

  private static async stats(userId: string, personId?: string) {
    const result = await db.rawQuery(
      `SELECT p.id AS id, ${BALANCE_SQL} AS balance, MAX(t.date) AS lastActivity
       FROM people p
       LEFT JOIN transactions t ON t.person_id = p.id
       WHERE p.user_id = ? ${personId ? 'AND p.id = ?' : ''}
       GROUP BY p.id`,
      personId ? [userId, personId] : [userId]
    )
    const rows = result[0] as Array<{ id: string; balance: number; lastActivity: Date | null }>
    return new Map(
      rows.map((row) => [
        row.id,
        {
          balance: Number(row.balance),
          lastActivity: row.lastActivity ? new Date(row.lastActivity).toISOString() : null,
        },
      ])
    )
  }

  private static async assertNameAvailable(user: User, name: string, exceptId?: string) {
    const query = Person.query().where('userId', user.id).where('name', name)
    if (exceptId) query.whereNot('id', exceptId)
    const clash = await query.first()
    if (clash) throw fieldError('name', 'You already have someone with this name', 'unique')
  }
}

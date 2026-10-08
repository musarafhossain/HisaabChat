import type { DateTime } from 'luxon'
import type Account from '#models/account'
import type Category from '#models/category'
import type RecurringOccurrence from '#models/recurring_occurrence'
import type RecurringRule from '#models/recurring_rule'
import type User from '#models/user'

const accountRef = (account?: Account | null) =>
  account ? { id: account.id, name: account.name, icon: account.icon, color: account.color } : null

const categoryRef = (category?: Category | null) =>
  category
    ? { id: category.id, name: category.name, icon: category.icon, color: category.color }
    : null

const isoDate = (value: DateTime) => value.toUTC().toISODate()!

/**
 * RecurringRuleDTO. Expects account, toAccount and category to be preloaded.
 * `nextDate` is the user's local date of the next occurrence (null once ended).
 */
export function ruleDto(rule: RecurringRule, user: User) {
  return {
    id: rule.id,
    type: rule.type,
    amount: rule.amount,
    account: accountRef(rule.account)!,
    toAccount: accountRef(rule.toAccount),
    category: categoryRef(rule.category),
    note: rule.note,
    frequency: rule.frequency,
    interval: rule.interval,
    dayOfMonth: rule.dayOfMonth,
    startDate: isoDate(rule.startDate),
    endDate: rule.endDate ? isoDate(rule.endDate) : null,
    autoCreate: rule.autoCreate,
    isActive: rule.isActive,
    nextDate: rule.isActive ? rule.nextRunAt.setZone(user.timezone).toISODate() : null,
  }
}

/** A PENDING (or handled) occurrence with its rule. */
export function occurrenceDto(occurrence: RecurringOccurrence, user: User) {
  return {
    id: occurrence.id,
    dueDate: isoDate(occurrence.dueDate),
    status: occurrence.status,
    transactionId: occurrence.transactionId,
    rule: ruleDto(occurrence.rule, user),
  }
}

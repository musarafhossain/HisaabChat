/* eslint-disable prettier/prettier */
import type { routes } from './index.ts'

export interface ApiDefinition {
  health: typeof routes['health']
  auth: {
    register: typeof routes['auth.register']
    login: typeof routes['auth.login']
    logout: typeof routes['auth.logout']
    logoutAll: typeof routes['auth.logoutAll']
  }
  me: {
    show: typeof routes['me.show']
    update: typeof routes['me.update']
    completeOnboarding: typeof routes['me.completeOnboarding']
  }
  accounts: {
    index: typeof routes['accounts.index']
    store: typeof routes['accounts.store']
    show: typeof routes['accounts.show']
    update: typeof routes['accounts.update']
    destroy: typeof routes['accounts.destroy']
    archive: typeof routes['accounts.archive']
    unarchive: typeof routes['accounts.unarchive']
    reconcile: typeof routes['accounts.reconcile']
  }
  recurring: {
    index: typeof routes['recurring.index']
    store: typeof routes['recurring.store']
    upcoming: typeof routes['recurring.upcoming']
    update: typeof routes['recurring.update']
    destroy: typeof routes['recurring.destroy']
    confirm: typeof routes['recurring.confirm']
    skip: typeof routes['recurring.skip']
  }
  people: {
    index: typeof routes['people.index']
    store: typeof routes['people.store']
    show: typeof routes['people.show']
    update: typeof routes['people.update']
    archive: typeof routes['people.archive']
    unarchive: typeof routes['people.unarchive']
    settle: typeof routes['people.settle']
  }
  categories: {
    index: typeof routes['categories.index']
    store: typeof routes['categories.store']
    reorder: typeof routes['categories.reorder']
    update: typeof routes['categories.update']
    archive: typeof routes['categories.archive']
    unarchive: typeof routes['categories.unarchive']
  }
  dashboard: typeof routes['dashboard']
  reports: {
    byCategory: typeof routes['reports.byCategory']
    trend: typeof routes['reports.trend']
  }
  budgets: {
    index: typeof routes['budgets.index']
    store: typeof routes['budgets.store']
    show: typeof routes['budgets.show']
    update: typeof routes['budgets.update']
    archive: typeof routes['budgets.archive']
    setOverride: typeof routes['budgets.setOverride']
    deleteOverride: typeof routes['budgets.deleteOverride']
  }
  transactions: {
    index: typeof routes['transactions.index']
    store: typeof routes['transactions.store']
    show: typeof routes['transactions.show']
    update: typeof routes['transactions.update']
    destroy: typeof routes['transactions.destroy']
  }
}

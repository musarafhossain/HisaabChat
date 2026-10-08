/* eslint-disable prettier/prettier */
import type { AdonisEndpoint } from '@tuyau/core/types'
import type { Registry } from './schema.d.ts'
import type { ApiDefinition } from './tree.d.ts'

const placeholder: any = {}

const routes = {
  'health': {
    methods: ["GET","HEAD"],
    pattern: '/api/v1/health',
    tokens: [{"old":"/api/v1/health","type":0,"val":"api","end":""},{"old":"/api/v1/health","type":0,"val":"v1","end":""},{"old":"/api/v1/health","type":0,"val":"health","end":""}],
    types: placeholder as Registry['health']['types'],
  },
  'auth.register': {
    methods: ["POST"],
    pattern: '/api/v1/auth/register',
    tokens: [{"old":"/api/v1/auth/register","type":0,"val":"api","end":""},{"old":"/api/v1/auth/register","type":0,"val":"v1","end":""},{"old":"/api/v1/auth/register","type":0,"val":"auth","end":""},{"old":"/api/v1/auth/register","type":0,"val":"register","end":""}],
    types: placeholder as Registry['auth.register']['types'],
  },
  'auth.login': {
    methods: ["POST"],
    pattern: '/api/v1/auth/login',
    tokens: [{"old":"/api/v1/auth/login","type":0,"val":"api","end":""},{"old":"/api/v1/auth/login","type":0,"val":"v1","end":""},{"old":"/api/v1/auth/login","type":0,"val":"auth","end":""},{"old":"/api/v1/auth/login","type":0,"val":"login","end":""}],
    types: placeholder as Registry['auth.login']['types'],
  },
  'auth.logout': {
    methods: ["POST"],
    pattern: '/api/v1/auth/logout',
    tokens: [{"old":"/api/v1/auth/logout","type":0,"val":"api","end":""},{"old":"/api/v1/auth/logout","type":0,"val":"v1","end":""},{"old":"/api/v1/auth/logout","type":0,"val":"auth","end":""},{"old":"/api/v1/auth/logout","type":0,"val":"logout","end":""}],
    types: placeholder as Registry['auth.logout']['types'],
  },
  'auth.logoutAll': {
    methods: ["POST"],
    pattern: '/api/v1/auth/logout-all',
    tokens: [{"old":"/api/v1/auth/logout-all","type":0,"val":"api","end":""},{"old":"/api/v1/auth/logout-all","type":0,"val":"v1","end":""},{"old":"/api/v1/auth/logout-all","type":0,"val":"auth","end":""},{"old":"/api/v1/auth/logout-all","type":0,"val":"logout-all","end":""}],
    types: placeholder as Registry['auth.logoutAll']['types'],
  },
  'me.show': {
    methods: ["GET","HEAD"],
    pattern: '/api/v1/me',
    tokens: [{"old":"/api/v1/me","type":0,"val":"api","end":""},{"old":"/api/v1/me","type":0,"val":"v1","end":""},{"old":"/api/v1/me","type":0,"val":"me","end":""}],
    types: placeholder as Registry['me.show']['types'],
  },
  'me.update': {
    methods: ["PATCH"],
    pattern: '/api/v1/me',
    tokens: [{"old":"/api/v1/me","type":0,"val":"api","end":""},{"old":"/api/v1/me","type":0,"val":"v1","end":""},{"old":"/api/v1/me","type":0,"val":"me","end":""}],
    types: placeholder as Registry['me.update']['types'],
  },
  'me.completeOnboarding': {
    methods: ["POST"],
    pattern: '/api/v1/me/onboarding/complete',
    tokens: [{"old":"/api/v1/me/onboarding/complete","type":0,"val":"api","end":""},{"old":"/api/v1/me/onboarding/complete","type":0,"val":"v1","end":""},{"old":"/api/v1/me/onboarding/complete","type":0,"val":"me","end":""},{"old":"/api/v1/me/onboarding/complete","type":0,"val":"onboarding","end":""},{"old":"/api/v1/me/onboarding/complete","type":0,"val":"complete","end":""}],
    types: placeholder as Registry['me.completeOnboarding']['types'],
  },
  'accounts.index': {
    methods: ["GET","HEAD"],
    pattern: '/api/v1/accounts',
    tokens: [{"old":"/api/v1/accounts","type":0,"val":"api","end":""},{"old":"/api/v1/accounts","type":0,"val":"v1","end":""},{"old":"/api/v1/accounts","type":0,"val":"accounts","end":""}],
    types: placeholder as Registry['accounts.index']['types'],
  },
  'accounts.store': {
    methods: ["POST"],
    pattern: '/api/v1/accounts',
    tokens: [{"old":"/api/v1/accounts","type":0,"val":"api","end":""},{"old":"/api/v1/accounts","type":0,"val":"v1","end":""},{"old":"/api/v1/accounts","type":0,"val":"accounts","end":""}],
    types: placeholder as Registry['accounts.store']['types'],
  },
  'accounts.show': {
    methods: ["GET","HEAD"],
    pattern: '/api/v1/accounts/:id',
    tokens: [{"old":"/api/v1/accounts/:id","type":0,"val":"api","end":""},{"old":"/api/v1/accounts/:id","type":0,"val":"v1","end":""},{"old":"/api/v1/accounts/:id","type":0,"val":"accounts","end":""},{"old":"/api/v1/accounts/:id","type":1,"val":"id","end":""}],
    types: placeholder as Registry['accounts.show']['types'],
  },
  'accounts.update': {
    methods: ["PATCH"],
    pattern: '/api/v1/accounts/:id',
    tokens: [{"old":"/api/v1/accounts/:id","type":0,"val":"api","end":""},{"old":"/api/v1/accounts/:id","type":0,"val":"v1","end":""},{"old":"/api/v1/accounts/:id","type":0,"val":"accounts","end":""},{"old":"/api/v1/accounts/:id","type":1,"val":"id","end":""}],
    types: placeholder as Registry['accounts.update']['types'],
  },
  'accounts.destroy': {
    methods: ["DELETE"],
    pattern: '/api/v1/accounts/:id',
    tokens: [{"old":"/api/v1/accounts/:id","type":0,"val":"api","end":""},{"old":"/api/v1/accounts/:id","type":0,"val":"v1","end":""},{"old":"/api/v1/accounts/:id","type":0,"val":"accounts","end":""},{"old":"/api/v1/accounts/:id","type":1,"val":"id","end":""}],
    types: placeholder as Registry['accounts.destroy']['types'],
  },
  'accounts.archive': {
    methods: ["POST"],
    pattern: '/api/v1/accounts/:id/archive',
    tokens: [{"old":"/api/v1/accounts/:id/archive","type":0,"val":"api","end":""},{"old":"/api/v1/accounts/:id/archive","type":0,"val":"v1","end":""},{"old":"/api/v1/accounts/:id/archive","type":0,"val":"accounts","end":""},{"old":"/api/v1/accounts/:id/archive","type":1,"val":"id","end":""},{"old":"/api/v1/accounts/:id/archive","type":0,"val":"archive","end":""}],
    types: placeholder as Registry['accounts.archive']['types'],
  },
  'accounts.unarchive': {
    methods: ["POST"],
    pattern: '/api/v1/accounts/:id/unarchive',
    tokens: [{"old":"/api/v1/accounts/:id/unarchive","type":0,"val":"api","end":""},{"old":"/api/v1/accounts/:id/unarchive","type":0,"val":"v1","end":""},{"old":"/api/v1/accounts/:id/unarchive","type":0,"val":"accounts","end":""},{"old":"/api/v1/accounts/:id/unarchive","type":1,"val":"id","end":""},{"old":"/api/v1/accounts/:id/unarchive","type":0,"val":"unarchive","end":""}],
    types: placeholder as Registry['accounts.unarchive']['types'],
  },
  'accounts.reconcile': {
    methods: ["POST"],
    pattern: '/api/v1/accounts/:id/reconcile',
    tokens: [{"old":"/api/v1/accounts/:id/reconcile","type":0,"val":"api","end":""},{"old":"/api/v1/accounts/:id/reconcile","type":0,"val":"v1","end":""},{"old":"/api/v1/accounts/:id/reconcile","type":0,"val":"accounts","end":""},{"old":"/api/v1/accounts/:id/reconcile","type":1,"val":"id","end":""},{"old":"/api/v1/accounts/:id/reconcile","type":0,"val":"reconcile","end":""}],
    types: placeholder as Registry['accounts.reconcile']['types'],
  },
  'recurring.index': {
    methods: ["GET","HEAD"],
    pattern: '/api/v1/recurring',
    tokens: [{"old":"/api/v1/recurring","type":0,"val":"api","end":""},{"old":"/api/v1/recurring","type":0,"val":"v1","end":""},{"old":"/api/v1/recurring","type":0,"val":"recurring","end":""}],
    types: placeholder as Registry['recurring.index']['types'],
  },
  'recurring.store': {
    methods: ["POST"],
    pattern: '/api/v1/recurring',
    tokens: [{"old":"/api/v1/recurring","type":0,"val":"api","end":""},{"old":"/api/v1/recurring","type":0,"val":"v1","end":""},{"old":"/api/v1/recurring","type":0,"val":"recurring","end":""}],
    types: placeholder as Registry['recurring.store']['types'],
  },
  'recurring.upcoming': {
    methods: ["GET","HEAD"],
    pattern: '/api/v1/recurring/upcoming',
    tokens: [{"old":"/api/v1/recurring/upcoming","type":0,"val":"api","end":""},{"old":"/api/v1/recurring/upcoming","type":0,"val":"v1","end":""},{"old":"/api/v1/recurring/upcoming","type":0,"val":"recurring","end":""},{"old":"/api/v1/recurring/upcoming","type":0,"val":"upcoming","end":""}],
    types: placeholder as Registry['recurring.upcoming']['types'],
  },
  'recurring.update': {
    methods: ["PATCH"],
    pattern: '/api/v1/recurring/:id',
    tokens: [{"old":"/api/v1/recurring/:id","type":0,"val":"api","end":""},{"old":"/api/v1/recurring/:id","type":0,"val":"v1","end":""},{"old":"/api/v1/recurring/:id","type":0,"val":"recurring","end":""},{"old":"/api/v1/recurring/:id","type":1,"val":"id","end":""}],
    types: placeholder as Registry['recurring.update']['types'],
  },
  'recurring.destroy': {
    methods: ["DELETE"],
    pattern: '/api/v1/recurring/:id',
    tokens: [{"old":"/api/v1/recurring/:id","type":0,"val":"api","end":""},{"old":"/api/v1/recurring/:id","type":0,"val":"v1","end":""},{"old":"/api/v1/recurring/:id","type":0,"val":"recurring","end":""},{"old":"/api/v1/recurring/:id","type":1,"val":"id","end":""}],
    types: placeholder as Registry['recurring.destroy']['types'],
  },
  'recurring.confirm': {
    methods: ["POST"],
    pattern: '/api/v1/recurring/occurrences/:id/confirm',
    tokens: [{"old":"/api/v1/recurring/occurrences/:id/confirm","type":0,"val":"api","end":""},{"old":"/api/v1/recurring/occurrences/:id/confirm","type":0,"val":"v1","end":""},{"old":"/api/v1/recurring/occurrences/:id/confirm","type":0,"val":"recurring","end":""},{"old":"/api/v1/recurring/occurrences/:id/confirm","type":0,"val":"occurrences","end":""},{"old":"/api/v1/recurring/occurrences/:id/confirm","type":1,"val":"id","end":""},{"old":"/api/v1/recurring/occurrences/:id/confirm","type":0,"val":"confirm","end":""}],
    types: placeholder as Registry['recurring.confirm']['types'],
  },
  'recurring.skip': {
    methods: ["POST"],
    pattern: '/api/v1/recurring/occurrences/:id/skip',
    tokens: [{"old":"/api/v1/recurring/occurrences/:id/skip","type":0,"val":"api","end":""},{"old":"/api/v1/recurring/occurrences/:id/skip","type":0,"val":"v1","end":""},{"old":"/api/v1/recurring/occurrences/:id/skip","type":0,"val":"recurring","end":""},{"old":"/api/v1/recurring/occurrences/:id/skip","type":0,"val":"occurrences","end":""},{"old":"/api/v1/recurring/occurrences/:id/skip","type":1,"val":"id","end":""},{"old":"/api/v1/recurring/occurrences/:id/skip","type":0,"val":"skip","end":""}],
    types: placeholder as Registry['recurring.skip']['types'],
  },
  'people.index': {
    methods: ["GET","HEAD"],
    pattern: '/api/v1/people',
    tokens: [{"old":"/api/v1/people","type":0,"val":"api","end":""},{"old":"/api/v1/people","type":0,"val":"v1","end":""},{"old":"/api/v1/people","type":0,"val":"people","end":""}],
    types: placeholder as Registry['people.index']['types'],
  },
  'people.store': {
    methods: ["POST"],
    pattern: '/api/v1/people',
    tokens: [{"old":"/api/v1/people","type":0,"val":"api","end":""},{"old":"/api/v1/people","type":0,"val":"v1","end":""},{"old":"/api/v1/people","type":0,"val":"people","end":""}],
    types: placeholder as Registry['people.store']['types'],
  },
  'people.show': {
    methods: ["GET","HEAD"],
    pattern: '/api/v1/people/:id',
    tokens: [{"old":"/api/v1/people/:id","type":0,"val":"api","end":""},{"old":"/api/v1/people/:id","type":0,"val":"v1","end":""},{"old":"/api/v1/people/:id","type":0,"val":"people","end":""},{"old":"/api/v1/people/:id","type":1,"val":"id","end":""}],
    types: placeholder as Registry['people.show']['types'],
  },
  'people.update': {
    methods: ["PATCH"],
    pattern: '/api/v1/people/:id',
    tokens: [{"old":"/api/v1/people/:id","type":0,"val":"api","end":""},{"old":"/api/v1/people/:id","type":0,"val":"v1","end":""},{"old":"/api/v1/people/:id","type":0,"val":"people","end":""},{"old":"/api/v1/people/:id","type":1,"val":"id","end":""}],
    types: placeholder as Registry['people.update']['types'],
  },
  'people.archive': {
    methods: ["POST"],
    pattern: '/api/v1/people/:id/archive',
    tokens: [{"old":"/api/v1/people/:id/archive","type":0,"val":"api","end":""},{"old":"/api/v1/people/:id/archive","type":0,"val":"v1","end":""},{"old":"/api/v1/people/:id/archive","type":0,"val":"people","end":""},{"old":"/api/v1/people/:id/archive","type":1,"val":"id","end":""},{"old":"/api/v1/people/:id/archive","type":0,"val":"archive","end":""}],
    types: placeholder as Registry['people.archive']['types'],
  },
  'people.unarchive': {
    methods: ["POST"],
    pattern: '/api/v1/people/:id/unarchive',
    tokens: [{"old":"/api/v1/people/:id/unarchive","type":0,"val":"api","end":""},{"old":"/api/v1/people/:id/unarchive","type":0,"val":"v1","end":""},{"old":"/api/v1/people/:id/unarchive","type":0,"val":"people","end":""},{"old":"/api/v1/people/:id/unarchive","type":1,"val":"id","end":""},{"old":"/api/v1/people/:id/unarchive","type":0,"val":"unarchive","end":""}],
    types: placeholder as Registry['people.unarchive']['types'],
  },
  'people.settle': {
    methods: ["POST"],
    pattern: '/api/v1/people/:id/settle',
    tokens: [{"old":"/api/v1/people/:id/settle","type":0,"val":"api","end":""},{"old":"/api/v1/people/:id/settle","type":0,"val":"v1","end":""},{"old":"/api/v1/people/:id/settle","type":0,"val":"people","end":""},{"old":"/api/v1/people/:id/settle","type":1,"val":"id","end":""},{"old":"/api/v1/people/:id/settle","type":0,"val":"settle","end":""}],
    types: placeholder as Registry['people.settle']['types'],
  },
  'categories.index': {
    methods: ["GET","HEAD"],
    pattern: '/api/v1/categories',
    tokens: [{"old":"/api/v1/categories","type":0,"val":"api","end":""},{"old":"/api/v1/categories","type":0,"val":"v1","end":""},{"old":"/api/v1/categories","type":0,"val":"categories","end":""}],
    types: placeholder as Registry['categories.index']['types'],
  },
  'categories.store': {
    methods: ["POST"],
    pattern: '/api/v1/categories',
    tokens: [{"old":"/api/v1/categories","type":0,"val":"api","end":""},{"old":"/api/v1/categories","type":0,"val":"v1","end":""},{"old":"/api/v1/categories","type":0,"val":"categories","end":""}],
    types: placeholder as Registry['categories.store']['types'],
  },
  'categories.reorder': {
    methods: ["PUT"],
    pattern: '/api/v1/categories/order',
    tokens: [{"old":"/api/v1/categories/order","type":0,"val":"api","end":""},{"old":"/api/v1/categories/order","type":0,"val":"v1","end":""},{"old":"/api/v1/categories/order","type":0,"val":"categories","end":""},{"old":"/api/v1/categories/order","type":0,"val":"order","end":""}],
    types: placeholder as Registry['categories.reorder']['types'],
  },
  'categories.update': {
    methods: ["PATCH"],
    pattern: '/api/v1/categories/:id',
    tokens: [{"old":"/api/v1/categories/:id","type":0,"val":"api","end":""},{"old":"/api/v1/categories/:id","type":0,"val":"v1","end":""},{"old":"/api/v1/categories/:id","type":0,"val":"categories","end":""},{"old":"/api/v1/categories/:id","type":1,"val":"id","end":""}],
    types: placeholder as Registry['categories.update']['types'],
  },
  'categories.archive': {
    methods: ["POST"],
    pattern: '/api/v1/categories/:id/archive',
    tokens: [{"old":"/api/v1/categories/:id/archive","type":0,"val":"api","end":""},{"old":"/api/v1/categories/:id/archive","type":0,"val":"v1","end":""},{"old":"/api/v1/categories/:id/archive","type":0,"val":"categories","end":""},{"old":"/api/v1/categories/:id/archive","type":1,"val":"id","end":""},{"old":"/api/v1/categories/:id/archive","type":0,"val":"archive","end":""}],
    types: placeholder as Registry['categories.archive']['types'],
  },
  'categories.unarchive': {
    methods: ["POST"],
    pattern: '/api/v1/categories/:id/unarchive',
    tokens: [{"old":"/api/v1/categories/:id/unarchive","type":0,"val":"api","end":""},{"old":"/api/v1/categories/:id/unarchive","type":0,"val":"v1","end":""},{"old":"/api/v1/categories/:id/unarchive","type":0,"val":"categories","end":""},{"old":"/api/v1/categories/:id/unarchive","type":1,"val":"id","end":""},{"old":"/api/v1/categories/:id/unarchive","type":0,"val":"unarchive","end":""}],
    types: placeholder as Registry['categories.unarchive']['types'],
  },
  'dashboard': {
    methods: ["GET","HEAD"],
    pattern: '/api/v1/dashboard',
    tokens: [{"old":"/api/v1/dashboard","type":0,"val":"api","end":""},{"old":"/api/v1/dashboard","type":0,"val":"v1","end":""},{"old":"/api/v1/dashboard","type":0,"val":"dashboard","end":""}],
    types: placeholder as Registry['dashboard']['types'],
  },
  'reports.byCategory': {
    methods: ["GET","HEAD"],
    pattern: '/api/v1/reports/categories',
    tokens: [{"old":"/api/v1/reports/categories","type":0,"val":"api","end":""},{"old":"/api/v1/reports/categories","type":0,"val":"v1","end":""},{"old":"/api/v1/reports/categories","type":0,"val":"reports","end":""},{"old":"/api/v1/reports/categories","type":0,"val":"categories","end":""}],
    types: placeholder as Registry['reports.byCategory']['types'],
  },
  'reports.trend': {
    methods: ["GET","HEAD"],
    pattern: '/api/v1/reports/trend',
    tokens: [{"old":"/api/v1/reports/trend","type":0,"val":"api","end":""},{"old":"/api/v1/reports/trend","type":0,"val":"v1","end":""},{"old":"/api/v1/reports/trend","type":0,"val":"reports","end":""},{"old":"/api/v1/reports/trend","type":0,"val":"trend","end":""}],
    types: placeholder as Registry['reports.trend']['types'],
  },
  'budgets.index': {
    methods: ["GET","HEAD"],
    pattern: '/api/v1/budgets',
    tokens: [{"old":"/api/v1/budgets","type":0,"val":"api","end":""},{"old":"/api/v1/budgets","type":0,"val":"v1","end":""},{"old":"/api/v1/budgets","type":0,"val":"budgets","end":""}],
    types: placeholder as Registry['budgets.index']['types'],
  },
  'budgets.store': {
    methods: ["POST"],
    pattern: '/api/v1/budgets',
    tokens: [{"old":"/api/v1/budgets","type":0,"val":"api","end":""},{"old":"/api/v1/budgets","type":0,"val":"v1","end":""},{"old":"/api/v1/budgets","type":0,"val":"budgets","end":""}],
    types: placeholder as Registry['budgets.store']['types'],
  },
  'budgets.show': {
    methods: ["GET","HEAD"],
    pattern: '/api/v1/budgets/:id',
    tokens: [{"old":"/api/v1/budgets/:id","type":0,"val":"api","end":""},{"old":"/api/v1/budgets/:id","type":0,"val":"v1","end":""},{"old":"/api/v1/budgets/:id","type":0,"val":"budgets","end":""},{"old":"/api/v1/budgets/:id","type":1,"val":"id","end":""}],
    types: placeholder as Registry['budgets.show']['types'],
  },
  'budgets.update': {
    methods: ["PATCH"],
    pattern: '/api/v1/budgets/:id',
    tokens: [{"old":"/api/v1/budgets/:id","type":0,"val":"api","end":""},{"old":"/api/v1/budgets/:id","type":0,"val":"v1","end":""},{"old":"/api/v1/budgets/:id","type":0,"val":"budgets","end":""},{"old":"/api/v1/budgets/:id","type":1,"val":"id","end":""}],
    types: placeholder as Registry['budgets.update']['types'],
  },
  'budgets.archive': {
    methods: ["POST"],
    pattern: '/api/v1/budgets/:id/archive',
    tokens: [{"old":"/api/v1/budgets/:id/archive","type":0,"val":"api","end":""},{"old":"/api/v1/budgets/:id/archive","type":0,"val":"v1","end":""},{"old":"/api/v1/budgets/:id/archive","type":0,"val":"budgets","end":""},{"old":"/api/v1/budgets/:id/archive","type":1,"val":"id","end":""},{"old":"/api/v1/budgets/:id/archive","type":0,"val":"archive","end":""}],
    types: placeholder as Registry['budgets.archive']['types'],
  },
  'budgets.setOverride': {
    methods: ["PUT"],
    pattern: '/api/v1/budgets/:id/overrides/:month',
    tokens: [{"old":"/api/v1/budgets/:id/overrides/:month","type":0,"val":"api","end":""},{"old":"/api/v1/budgets/:id/overrides/:month","type":0,"val":"v1","end":""},{"old":"/api/v1/budgets/:id/overrides/:month","type":0,"val":"budgets","end":""},{"old":"/api/v1/budgets/:id/overrides/:month","type":1,"val":"id","end":""},{"old":"/api/v1/budgets/:id/overrides/:month","type":0,"val":"overrides","end":""},{"old":"/api/v1/budgets/:id/overrides/:month","type":1,"val":"month","end":""}],
    types: placeholder as Registry['budgets.setOverride']['types'],
  },
  'budgets.deleteOverride': {
    methods: ["DELETE"],
    pattern: '/api/v1/budgets/:id/overrides/:month',
    tokens: [{"old":"/api/v1/budgets/:id/overrides/:month","type":0,"val":"api","end":""},{"old":"/api/v1/budgets/:id/overrides/:month","type":0,"val":"v1","end":""},{"old":"/api/v1/budgets/:id/overrides/:month","type":0,"val":"budgets","end":""},{"old":"/api/v1/budgets/:id/overrides/:month","type":1,"val":"id","end":""},{"old":"/api/v1/budgets/:id/overrides/:month","type":0,"val":"overrides","end":""},{"old":"/api/v1/budgets/:id/overrides/:month","type":1,"val":"month","end":""}],
    types: placeholder as Registry['budgets.deleteOverride']['types'],
  },
  'transactions.index': {
    methods: ["GET","HEAD"],
    pattern: '/api/v1/transactions',
    tokens: [{"old":"/api/v1/transactions","type":0,"val":"api","end":""},{"old":"/api/v1/transactions","type":0,"val":"v1","end":""},{"old":"/api/v1/transactions","type":0,"val":"transactions","end":""}],
    types: placeholder as Registry['transactions.index']['types'],
  },
  'transactions.store': {
    methods: ["POST"],
    pattern: '/api/v1/transactions',
    tokens: [{"old":"/api/v1/transactions","type":0,"val":"api","end":""},{"old":"/api/v1/transactions","type":0,"val":"v1","end":""},{"old":"/api/v1/transactions","type":0,"val":"transactions","end":""}],
    types: placeholder as Registry['transactions.store']['types'],
  },
  'transactions.show': {
    methods: ["GET","HEAD"],
    pattern: '/api/v1/transactions/:id',
    tokens: [{"old":"/api/v1/transactions/:id","type":0,"val":"api","end":""},{"old":"/api/v1/transactions/:id","type":0,"val":"v1","end":""},{"old":"/api/v1/transactions/:id","type":0,"val":"transactions","end":""},{"old":"/api/v1/transactions/:id","type":1,"val":"id","end":""}],
    types: placeholder as Registry['transactions.show']['types'],
  },
  'transactions.update': {
    methods: ["PATCH"],
    pattern: '/api/v1/transactions/:id',
    tokens: [{"old":"/api/v1/transactions/:id","type":0,"val":"api","end":""},{"old":"/api/v1/transactions/:id","type":0,"val":"v1","end":""},{"old":"/api/v1/transactions/:id","type":0,"val":"transactions","end":""},{"old":"/api/v1/transactions/:id","type":1,"val":"id","end":""}],
    types: placeholder as Registry['transactions.update']['types'],
  },
  'transactions.destroy': {
    methods: ["DELETE"],
    pattern: '/api/v1/transactions/:id',
    tokens: [{"old":"/api/v1/transactions/:id","type":0,"val":"api","end":""},{"old":"/api/v1/transactions/:id","type":0,"val":"v1","end":""},{"old":"/api/v1/transactions/:id","type":0,"val":"transactions","end":""},{"old":"/api/v1/transactions/:id","type":1,"val":"id","end":""}],
    types: placeholder as Registry['transactions.destroy']['types'],
  },
} as const satisfies Record<string, AdonisEndpoint>

export { routes }

export const registry = {
  routes,
  $tree: {} as ApiDefinition,
}

declare module '@tuyau/core/types' {
  export interface UserRegistry {
    routes: typeof routes
    $tree: ApiDefinition
  }
}

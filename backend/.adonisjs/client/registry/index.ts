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

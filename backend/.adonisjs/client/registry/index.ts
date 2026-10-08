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

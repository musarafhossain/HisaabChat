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
  }
}

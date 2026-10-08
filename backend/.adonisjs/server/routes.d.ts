import '@adonisjs/core/types/http'

type ParamValue = string | number | bigint | boolean

export type ScannedRoutes = {
  ALL: {
    'health': { paramsTuple?: []; params?: {} }
    'auth.register': { paramsTuple?: []; params?: {} }
    'auth.login': { paramsTuple?: []; params?: {} }
    'auth.logout': { paramsTuple?: []; params?: {} }
    'auth.logoutAll': { paramsTuple?: []; params?: {} }
    'me.show': { paramsTuple?: []; params?: {} }
    'me.update': { paramsTuple?: []; params?: {} }
    'me.completeOnboarding': { paramsTuple?: []; params?: {} }
    'accounts.index': { paramsTuple?: []; params?: {} }
    'accounts.store': { paramsTuple?: []; params?: {} }
    'accounts.show': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'accounts.update': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'accounts.destroy': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'accounts.archive': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'accounts.unarchive': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'accounts.reconcile': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'recurring.index': { paramsTuple?: []; params?: {} }
    'recurring.store': { paramsTuple?: []; params?: {} }
    'recurring.upcoming': { paramsTuple?: []; params?: {} }
    'recurring.update': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'recurring.destroy': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'recurring.confirm': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'recurring.skip': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'people.index': { paramsTuple?: []; params?: {} }
    'people.store': { paramsTuple?: []; params?: {} }
    'people.show': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'people.update': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'people.archive': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'people.unarchive': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'people.settle': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'categories.index': { paramsTuple?: []; params?: {} }
    'categories.store': { paramsTuple?: []; params?: {} }
    'categories.reorder': { paramsTuple?: []; params?: {} }
    'categories.update': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'categories.archive': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'categories.unarchive': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'dashboard': { paramsTuple?: []; params?: {} }
    'reports.byCategory': { paramsTuple?: []; params?: {} }
    'reports.trend': { paramsTuple?: []; params?: {} }
    'budgets.index': { paramsTuple?: []; params?: {} }
    'budgets.store': { paramsTuple?: []; params?: {} }
    'budgets.show': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'budgets.update': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'budgets.archive': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'budgets.setOverride': { paramsTuple: [ParamValue,ParamValue]; params: {'id': ParamValue,'month': ParamValue} }
    'budgets.deleteOverride': { paramsTuple: [ParamValue,ParamValue]; params: {'id': ParamValue,'month': ParamValue} }
    'transactions.index': { paramsTuple?: []; params?: {} }
    'transactions.store': { paramsTuple?: []; params?: {} }
    'transactions.show': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'transactions.update': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'transactions.destroy': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
  }
  GET: {
    'health': { paramsTuple?: []; params?: {} }
    'me.show': { paramsTuple?: []; params?: {} }
    'accounts.index': { paramsTuple?: []; params?: {} }
    'accounts.show': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'recurring.index': { paramsTuple?: []; params?: {} }
    'recurring.upcoming': { paramsTuple?: []; params?: {} }
    'people.index': { paramsTuple?: []; params?: {} }
    'people.show': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'categories.index': { paramsTuple?: []; params?: {} }
    'dashboard': { paramsTuple?: []; params?: {} }
    'reports.byCategory': { paramsTuple?: []; params?: {} }
    'reports.trend': { paramsTuple?: []; params?: {} }
    'budgets.index': { paramsTuple?: []; params?: {} }
    'budgets.show': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'transactions.index': { paramsTuple?: []; params?: {} }
    'transactions.show': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
  }
  HEAD: {
    'health': { paramsTuple?: []; params?: {} }
    'me.show': { paramsTuple?: []; params?: {} }
    'accounts.index': { paramsTuple?: []; params?: {} }
    'accounts.show': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'recurring.index': { paramsTuple?: []; params?: {} }
    'recurring.upcoming': { paramsTuple?: []; params?: {} }
    'people.index': { paramsTuple?: []; params?: {} }
    'people.show': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'categories.index': { paramsTuple?: []; params?: {} }
    'dashboard': { paramsTuple?: []; params?: {} }
    'reports.byCategory': { paramsTuple?: []; params?: {} }
    'reports.trend': { paramsTuple?: []; params?: {} }
    'budgets.index': { paramsTuple?: []; params?: {} }
    'budgets.show': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'transactions.index': { paramsTuple?: []; params?: {} }
    'transactions.show': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
  }
  POST: {
    'auth.register': { paramsTuple?: []; params?: {} }
    'auth.login': { paramsTuple?: []; params?: {} }
    'auth.logout': { paramsTuple?: []; params?: {} }
    'auth.logoutAll': { paramsTuple?: []; params?: {} }
    'me.completeOnboarding': { paramsTuple?: []; params?: {} }
    'accounts.store': { paramsTuple?: []; params?: {} }
    'accounts.archive': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'accounts.unarchive': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'accounts.reconcile': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'recurring.store': { paramsTuple?: []; params?: {} }
    'recurring.confirm': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'recurring.skip': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'people.store': { paramsTuple?: []; params?: {} }
    'people.archive': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'people.unarchive': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'people.settle': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'categories.store': { paramsTuple?: []; params?: {} }
    'categories.archive': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'categories.unarchive': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'budgets.store': { paramsTuple?: []; params?: {} }
    'budgets.archive': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'transactions.store': { paramsTuple?: []; params?: {} }
  }
  PATCH: {
    'me.update': { paramsTuple?: []; params?: {} }
    'accounts.update': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'recurring.update': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'people.update': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'categories.update': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'budgets.update': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'transactions.update': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
  }
  DELETE: {
    'accounts.destroy': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'recurring.destroy': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
    'budgets.deleteOverride': { paramsTuple: [ParamValue,ParamValue]; params: {'id': ParamValue,'month': ParamValue} }
    'transactions.destroy': { paramsTuple: [ParamValue]; params: {'id': ParamValue} }
  }
  PUT: {
    'categories.reorder': { paramsTuple?: []; params?: {} }
    'budgets.setOverride': { paramsTuple: [ParamValue,ParamValue]; params: {'id': ParamValue,'month': ParamValue} }
  }
}
declare module '@adonisjs/core/types/http' {
  export interface RoutesList extends ScannedRoutes {}
}
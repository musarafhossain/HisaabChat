/*
|--------------------------------------------------------------------------
| Routes file
|--------------------------------------------------------------------------
|
| The routes file is used for defining the HTTP routes.
|
*/

import { middleware } from '#start/kernel'
import router from '@adonisjs/core/services/router'
import { controllers } from '#generated/controllers'
import { authThrottle } from '#start/limiter'

router.get('/', () => {
  return { name: 'HisaabChat API', docs: '/api/v1/health' }
})

router
  .group(() => {
    router.get('health', [controllers.Health, 'show']).as('health')

    /**
     * Public auth endpoints (rate limited per IP).
     */
    router
      .group(() => {
        router.post('register', [controllers.Auth, 'register']).as('register')
        router.post('login', [controllers.Auth, 'login']).as('login')
      })
      .prefix('auth')
      .as('auth')
      .use(authThrottle)

    /**
     * Authenticated endpoints.
     */
    router
      .group(() => {
        router.post('auth/logout', [controllers.Auth, 'logout']).as('auth.logout')
        router.post('auth/logout-all', [controllers.Auth, 'logoutAll']).as('auth.logoutAll')

        router.get('me', [controllers.Me, 'show']).as('me.show')
        router.patch('me', [controllers.Me, 'update']).as('me.update')
        router
          .post('me/onboarding/complete', [controllers.Me, 'completeOnboarding'])
          .as('me.completeOnboarding')

        router
          .group(() => {
            router.get('/', [controllers.Accounts, 'index']).as('index')
            router.post('/', [controllers.Accounts, 'store']).as('store')
            router.get(':id', [controllers.Accounts, 'show']).as('show')
            router.patch(':id', [controllers.Accounts, 'update']).as('update')
            router.delete(':id', [controllers.Accounts, 'destroy']).as('destroy')
            router.post(':id/archive', [controllers.Accounts, 'archive']).as('archive')
            router.post(':id/unarchive', [controllers.Accounts, 'unarchive']).as('unarchive')
            router.post(':id/reconcile', [controllers.Accounts, 'reconcile']).as('reconcile')
          })
          .prefix('accounts')
          .as('accounts')
          .where('id', router.matchers.uuid())

        router
          .group(() => {
            router.get('/', [controllers.Categories, 'index']).as('index')
            router.post('/', [controllers.Categories, 'store']).as('store')
            router.put('order', [controllers.Categories, 'reorder']).as('reorder')
            router.patch(':id', [controllers.Categories, 'update']).as('update')
            router.post(':id/archive', [controllers.Categories, 'archive']).as('archive')
            router.post(':id/unarchive', [controllers.Categories, 'unarchive']).as('unarchive')
          })
          .prefix('categories')
          .as('categories')
          .where('id', router.matchers.uuid())

        router.get('dashboard', [controllers.Reports, 'dashboard']).as('dashboard')
        router
          .group(() => {
            router.get('categories', [controllers.Reports, 'byCategory']).as('byCategory')
            router.get('trend', [controllers.Reports, 'trend']).as('trend')
          })
          .prefix('reports')
          .as('reports')

        router
          .group(() => {
            router.get('/', [controllers.Budgets, 'index']).as('index')
            router.post('/', [controllers.Budgets, 'store']).as('store')
            router.get(':id', [controllers.Budgets, 'show']).as('show')
            router.patch(':id', [controllers.Budgets, 'update']).as('update')
            router.post(':id/archive', [controllers.Budgets, 'archive']).as('archive')
            router
              .put(':id/overrides/:month', [controllers.Budgets, 'setOverride'])
              .as('setOverride')
            router
              .delete(':id/overrides/:month', [controllers.Budgets, 'deleteOverride'])
              .as('deleteOverride')
          })
          .prefix('budgets')
          .as('budgets')
          .where('id', router.matchers.uuid())

        router
          .group(() => {
            router.get('/', [controllers.Transactions, 'index']).as('index')
            router.post('/', [controllers.Transactions, 'store']).as('store')
            router.get(':id', [controllers.Transactions, 'show']).as('show')
            router.patch(':id', [controllers.Transactions, 'update']).as('update')
            router.delete(':id', [controllers.Transactions, 'destroy']).as('destroy')
          })
          .prefix('transactions')
          .as('transactions')
          .where('id', router.matchers.uuid())
      })
      .use(middleware.auth())
  })
  .prefix('/api/v1')

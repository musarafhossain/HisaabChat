import { test } from '@japa/runner'
import { formatMoney, toDecimalString, toPaise } from '#services/money'

test.group('money / toPaise', () => {
  test('parses "{input}" as {expected} paise')
    .with([
      { input: '1250.50', expected: 125050 },
      { input: '1,250.5', expected: 125050 },
      { input: '120', expected: 12000 },
      { input: '0.05', expected: 5 },
      { input: '-20', expected: -2000 },
      { input: 99.99, expected: 9999 },
    ])
    .run(({ assert }, { input, expected }) => {
      assert.equal(toPaise(input), expected)
    })

  test('rejects "{input}"')
    .with([{ input: '1.234' }, { input: 'abc' }, { input: '' }, { input: '1e5' }, { input: '12.' }])
    .run(({ assert }, { input }) => {
      assert.throws(() => toPaise(input))
    })
})

test.group('money / formatting', () => {
  test('formats decimal strings for CSV', ({ assert }) => {
    assert.equal(toDecimalString(125050), '1250.50')
    assert.equal(toDecimalString(5), '0.05')
    assert.equal(toDecimalString(-2000), '-20.00')
  })

  test('formats with Indian digit grouping', ({ assert }) => {
    assert.equal(formatMoney(12_500_000), '₹1,25,000')
    assert.equal(formatMoney(125_050), '₹1,250.50')
  })
})

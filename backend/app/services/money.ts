/**
 * Money helpers. All amounts are integers in minor units (paise).
 * Never use floating point arithmetic on money.
 */

const DECIMAL_PATTERN = /^(-)?(\d+)(?:\.(\d{1,2}))?$/

/**
 * Parses a decimal rupee string ("1,250.5", "-20", "0.05") into paise.
 * Throws on anything that isn't a plain number with at most 2 decimals.
 */
export function toPaise(input: string | number): number {
  const text = String(input).replaceAll(',', '').trim()
  const match = DECIMAL_PATTERN.exec(text)
  if (!match) {
    throw new Error(`Invalid money amount: "${input}"`)
  }

  const [, sign, rupees, fraction = ''] = match
  const paise = Number(rupees) * 100 + Number(fraction.padEnd(2, '0'))
  if (!Number.isSafeInteger(paise)) {
    throw new Error(`Money amount out of range: "${input}"`)
  }
  return sign ? -paise : paise
}

/**
 * Formats paise as a plain decimal string ("125050" -> "1250.50"), used
 * for CSV exports where spreadsheet apps need a machine-readable value.
 */
export function toDecimalString(paise: number): string {
  const sign = paise < 0 ? '-' : ''
  const abs = Math.abs(paise)
  const rupees = Math.trunc(abs / 100)
  const fraction = String(abs % 100).padStart(2, '0')
  return `${sign}${rupees}.${fraction}`
}

/**
 * Formats paise for humans using Indian digit grouping ("₹1,25,050.50").
 */
export function formatMoney(paise: number, currency = 'INR', locale = 'en-IN'): string {
  return new Intl.NumberFormat(locale, {
    style: 'currency',
    currency,
    minimumFractionDigits: paise % 100 === 0 ? 0 : 2,
    maximumFractionDigits: 2,
  }).format(paise / 100)
}

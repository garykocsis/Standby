import { formatUnits } from 'viem'

/// Both canonical demo currencies carry six decimals.
const CURRENCY_DECIMALS = 6

/**
 * Formats a raw currency quantity for display.
 *
 * Presentation only: the value formatted here was read from the chain, and formatting it changes nothing
 * about where it came from.
 */
export function formatCurrency(amount) {
  if (amount === undefined || amount === null) return '—'

  const [whole, fraction = ''] = formatUnits(amount, CURRENCY_DECIMALS).split('.')

  const grouped = BigInt(whole).toLocaleString('en-US')

  return `${grouped}.${fraction.padEnd(CURRENCY_DECIMALS, '0')}`
}

/** Formats a raw currency quantity with its unit. */
export function formatUsdc(amount) {
  return `${formatCurrency(amount)} MockUSDC`
}

/** Formats a raw currency quantity with its unit. */
export function formatUstb(amount) {
  return `${formatCurrency(amount)} MockUSTB`
}

/** Shortens an address for display. Full addresses remain available on hover. */
export function shortAddress(address) {
  if (!address) return '—'

  return `${address.slice(0, 6)}…${address.slice(-4)}`
}

/** Formats a Unix timestamp for display. */
export function formatTimestamp(timestamp) {
  if (timestamp === undefined || timestamp === null) return '—'

  return new Date(Number(timestamp) * 1000).toISOString().replace('T', ' ').slice(0, 19)
}

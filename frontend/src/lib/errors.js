import { decodeErrorResult, isHex } from 'viem'

import {
  actorAwareTestRouterAbi,
  exerciseRouterAbi,
  mockUsdcAbi,
  poolManagerAbi,
  standbyHookAbi,
} from './contracts.js'

/// The two ERC-7751 wrapper errors the pinned Uniswap v4 libraries revert with. A failed Hook callback is
/// wrapped by `Hooks` rather than bubbled raw, so the Standby reason arrives nested inside one of these.
/// They are Uniswap plumbing, not Standby semantics, and they carry no economic content of their own.
const wrapperErrorsAbi = [
  {
    type: 'error',
    name: 'WrappedError',
    inputs: [
      { name: 'target', type: 'address' },
      { name: 'selector', type: 'bytes4' },
      { name: 'reason', type: 'bytes' },
      { name: 'details', type: 'bytes' },
    ],
  },
  { type: 'error', name: 'HookCallFailed', inputs: [] },
]

const knownErrorsAbi = [
  ...standbyHookAbi,
  ...exerciseRouterAbi,
  ...actorAwareTestRouterAbi,
  ...poolManagerAbi,
  ...mockUsdcAbi,
  ...wrapperErrorsAbi,
]

/** Pulls the raw revert data out of whatever error shape the node and the client produced. */
function revertData(error) {
  const seen = new Set()

  let current = error

  while (current && typeof current === 'object' && !seen.has(current)) {
    seen.add(current)

    if (isHex(current.data) && current.data.length > 2) return current.data
    if (isHex(current.data?.data) && current.data.data.length > 2) return current.data.data

    current = current.cause ?? null
  }

  return null
}

/**
 * Decodes a refused transition into the reason the protocol actually gave.
 *
 * It unwraps the ERC-7751 wrappers until it reaches the innermost reason, so a Standby rejection is
 * reported as the Standby error it is — with the quantities the contract compared — rather than as a
 * generic Uniswap hook failure. The result is evidence about a transaction that did not happen; it is
 * never protocol state.
 */
export function decodeRejection(error) {
  const data = revertData(error)

  if (!data) {
    return { name: null, args: [], data: null, message: error?.shortMessage ?? error?.message ?? String(error) }
  }

  let current = data
  const wrappers = []

  for (let depth = 0; depth < 8; depth += 1) {
    let decoded

    try {
      decoded = decodeErrorResult({ abi: knownErrorsAbi, data: current })
    } catch {
      return { name: null, args: [], data: current, wrappers, message: `Undecodable revert data ${current}` }
    }

    if (decoded.errorName === 'WrappedError') {
      const [target, selector, reason] = decoded.args

      wrappers.push({ target, selector })

      if (!isHex(reason) || reason.length <= 2) {
        return { name: 'WrappedError', args: decoded.args, data: current, wrappers, message: 'Empty wrapped reason' }
      }

      current = reason
      continue
    }

    return {
      name: decoded.errorName,
      args: decoded.args ?? [],
      data: current,
      wrappers,
      message: formatRejection(decoded.errorName, decoded.args ?? []),
    }
  }

  return { name: null, args: [], data: current, wrappers, message: 'Revert data nested beyond the decoding bound' }
}

/** Renders a decoded rejection as its signature with the arguments the contract supplied. */
function formatRejection(name, args) {
  if (args.length === 0) return `${name}()`

  return `${name}(${args.map((arg) => String(arg)).join(', ')})`
}

/**
 * Whether a rejection is the Standby backing requirement refusing a transition.
 *
 * This is the one refusal the canonical A3 must produce. Anything else — eligibility, allowance, balance,
 * the service domain, or an unrelated Uniswap failure — is a different rejection and is shown as such.
 */
export function isBackingRejection(rejection) {
  return rejection?.name === 'StandbyHook__InsufficientProspectiveBacking'
}

import { useCallback, useState } from 'react'

import { decodeRejection } from '../lib/errors.js'
import { admitCommitment, exerciseCommitment, ordinarySwap } from '../lib/standby.js'

/**
 * The four canonical judged actions, as React state around the production calls in `lib/standby.js`.
 *
 *   A1  StandbyHook.establishCommitment      as the service's establishment authority
 *   A2  ActorAwareTestRouter.swap            as the eligible trader, through the trusted perimeter
 *   A3  ActorAwareTestRouter.swap            the same call, with a quantity that destroys required backing
 *   A4  ExerciseRouter.exercise              as the commitment's own exercise authority
 *
 * Nothing is optimistically applied here. An action records the transaction that actually happened and then
 * asks the caller to re-read authoritative state; the interface never advances its own economic picture.
 */
export function useDemoActions(clients, config, onSettled) {
  const [pending, setPending] = useState(null)
  const [result, setResult] = useState(null)

  const perform = useCallback(
    async (action, run) => {
      setPending(action)

      try {
        setResult(await run())
      } catch (error) {
        setResult({ action, status: 'FAILED', rejection: decodeRejection(error) })
      } finally {
        setPending(null)
        onSettled()
      }
    },
    [onSettled],
  )

  return {
    pending,
    result,

    admitCommitment: useCallback(
      () => perform('A1', () => admitCommitment(clients, config)),
      [perform, clients, config],
    ),

    compatibleOrdinarySwap: useCallback(
      (service) =>
        perform('A2', () =>
          ordinarySwap(clients, config, {
            action: 'A2',
            service,
            amountOut: config.parameters.compatibleSwapOutput,
          }),
        ),
      [perform, clients, config],
    ),

    attemptDestructiveOrdinarySwap: useCallback(
      (service) =>
        perform('A3', () =>
          ordinarySwap(clients, config, {
            action: 'A3',
            service,
            amountOut: config.parameters.destructiveSwapOutput,
          }),
        ),
      [perform, clients, config],
    ),

    exerciseCommitment: useCallback(
      (commitment) => perform('A4', () => exerciseCommitment(clients, config, commitment)),
      [perform, clients, config],
    ),
  }
}

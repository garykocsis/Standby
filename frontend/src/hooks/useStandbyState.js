import { useCallback, useEffect, useState } from 'react'

import { readStandbyState } from '../lib/standby.js'

/**
 * Reads the authoritative economic state of the service.
 *
 * Every field is a production read:
 *
 *   Supporting Capacity   -> StandbyHook.supportingCapacity()
 *   Capacity Obligation   -> StandbyHook.aggregateObligation()
 *   service basis         -> StandbyHook.protectedExecutionService() / serviceId()
 *   Beneficiary balance   -> MockUSDC.balanceOf(beneficiary)
 *   price and tick        -> PoolManager storage
 *
 * Nothing is computed, accumulated, or remembered between reads. The `S >= O` relation the interface
 * displays is a comparison of two values it was given, not a derivation of either, and the protocol decides
 * every transition against its own derivation regardless of what is on screen.
 */
export function useStandbyState(clients, config, beneficiary, refreshKey) {
  const [state, setState] = useState({ data: null, error: null, loading: true })

  const read = useCallback(
    () => readStandbyState(clients, config, beneficiary),
    [clients, config, beneficiary],
  )

  useEffect(() => {
    let live = true

    setState((current) => ({ ...current, loading: true }))

    read()
      .then((data) => live && setState({ data, error: null, loading: false }))
      .catch((error) => live && setState({ data: null, error, loading: false }))

    return () => {
      live = false
    }
  }, [read, refreshKey])

  return state
}

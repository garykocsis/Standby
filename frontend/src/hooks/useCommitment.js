import { useCallback, useEffect, useState } from 'react'

import { readCommitment } from '../lib/standby.js'

/**
 * Reads the commitment the service currently references, through the Hook's own bounded
 * enforcement-reference index.
 *
 * Nothing is cached and nothing is remembered: a reload re-reads which commitment exists, and every field
 * shown is a persisted fact read straight back from the Hook.
 */
export function useCommitment(clients, config, refreshKey) {
  const [commitment, setCommitment] = useState({ id: null, record: null, error: null, loading: true })

  const read = useCallback(() => readCommitment(clients, config), [clients, config])

  useEffect(() => {
    let live = true

    setCommitment((current) => ({ ...current, loading: true }))

    read()
      .then((next) => live && setCommitment({ ...next, error: null, loading: false }))
      .catch((error) => live && setCommitment({ id: null, record: null, error, loading: false }))

    return () => {
      live = false
    }
  }, [read, refreshKey])

  return commitment
}

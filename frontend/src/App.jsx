import { useCallback, useEffect, useMemo, useState } from 'react'

import ActionPanel from './components/ActionPanel.jsx'
import ActionResult from './components/ActionResult.jsx'
import CommitmentPanel from './components/CommitmentPanel.jsx'
import StandbyStatePanel from './components/StandbyStatePanel.jsx'
import { useCommitment } from './hooks/useCommitment.js'
import { useDemoActions } from './hooks/useDemoActions.js'
import { useStandbyState } from './hooks/useStandbyState.js'
import { loadDemoConfig } from './lib/contracts.js'
import { createClients } from './lib/rpc.js'
import { shortAddress } from './lib/format.js'

/**
 * The judge-facing instrumentation for the canonical Standby demonstration.
 *
 * It is instrumentation and not a second state machine. It holds no economic state of its own: after every
 * action it waits for the receipt or the revert, re-reads authoritative state from the chain, and renders
 * what it read. A full page reload therefore reconstructs the current economic truth from the chain alone —
 * there is nothing else for it to reconstruct from.
 */
export default function App() {
  const [config, setConfig] = useState(null)
  const [configError, setConfigError] = useState(null)
  const [refreshKey, setRefreshKey] = useState(0)

  useEffect(() => {
    loadDemoConfig().then(setConfig).catch(setConfigError)
  }, [])

  const refresh = useCallback(() => setRefreshKey((key) => key + 1), [])

  if (configError) {
    return (
      <Shell>
        <div className="rounded-xl border border-rose-800 bg-rose-950/40 p-6 text-sm text-rose-200">
          {configError.message}
        </div>
      </Shell>
    )
  }

  if (!config) {
    return (
      <Shell>
        <div className="text-slate-400">Loading the deployed demo manifest…</div>
      </Shell>
    )
  }

  return <Demo config={config} refreshKey={refreshKey} refresh={refresh} />
}

function Demo({ config, refreshKey, refresh }) {
  const clients = useMemo(() => createClients(config), [config])

  const commitment = useCommitment(clients, config, refreshKey)

  const beneficiary = commitment.record?.beneficiary ?? config.actors.beneficiary

  const state = useStandbyState(clients, config, beneficiary, refreshKey)

  const actions = useDemoActions(clients, config, refresh)

  const handlers = {
    pending: actions.pending,
    admitCommitment: () => actions.admitCommitment(),
    compatibleOrdinarySwap: () => actions.compatibleOrdinarySwap(state.data?.service),
    attemptDestructiveOrdinarySwap: () => actions.attemptDestructiveOrdinarySwap(state.data?.service),
    exerciseCommitment: (target) => actions.exerciseCommitment(target),
  }

  return (
    <Shell config={config}>
      {state.error && (
        <div className="rounded-xl border border-rose-800 bg-rose-950/40 p-4 text-sm text-rose-200">
          Could not read authoritative state: {state.error.shortMessage ?? state.error.message}
        </div>
      )}

      <div className="grid gap-6 lg:grid-cols-[minmax(0,3fr)_minmax(0,2fr)]">
        <div className="space-y-6">
          <StandbyStatePanel state={state.data} commitment={commitment} loading={state.loading} />
          <CommitmentPanel commitment={commitment} />
        </div>

        <div className="space-y-6">
          <ActionPanel config={config} commitment={commitment} actions={handlers} />
          <ActionResult result={actions.result} />
        </div>
      </div>
    </Shell>
  )
}

function Shell({ config, children }) {
  return (
    <div className="min-h-screen bg-slate-950 text-slate-200">
      <div className="mx-auto max-w-6xl space-y-6 px-6 py-10">
        <header className="space-y-2">
          <h1 className="text-2xl font-semibold text-slate-50">Standby</h1>
          <p className="text-sm text-slate-400">
            Protocol-enforced future execution capacity from shared AMM liquidity.{' '}
            <span className="text-slate-300">Standby doesn&rsquo;t reserve liquidity. It protects capacity.</span>
          </p>
          {config && (
            <p className="font-mono text-[11px] text-slate-600">
              chain {config.chainId} · {config.rpcUrl} · hook {shortAddress(config.addresses.hook)} · authoritative
              economic state below is read from this chain
            </p>
          )}
        </header>

        {children}

        <footer className="border-t border-slate-900 pt-4 text-xs text-slate-600">
          Demonstration of one configured Standby service on a deterministic local chain with mock
          currencies. It does not establish guaranteed input price, zero slippage, universal asset support,
          or execution independent of validity, eligibility, authority, and service-domain requirements.
        </footer>
      </div>
    </div>
  )
}

import { formatUsdc, shortAddress } from '../lib/format.js'

/// One authoritative quantity, with the production read it came from.
function Reading({ label, value, source, emphasis = false }) {
  return (
    <div className={`rounded-lg border p-4 ${emphasis ? 'border-sky-700 bg-sky-950/40' : 'border-slate-800 bg-slate-900/60'}`}>
      <div className="text-xs uppercase tracking-wide text-slate-400">{label}</div>
      <div className="mt-1 font-mono text-lg text-slate-100">{value}</div>
      <div className="mt-1 font-mono text-[11px] text-slate-500">{source}</div>
    </div>
  )
}

/**
 * The proof-minimal authoritative state of the service.
 *
 * Every value on this panel was read from the Hook, the PoolManager, or a token contract on the read that
 * produced this render. The backing relation is a comparison of two values the protocol supplied; the
 * protocol enforces it against its own derivation, not against this display.
 */
export default function StandbyStatePanel({ state, commitment, loading }) {
  if (!state) {
    return (
      <section className="rounded-xl border border-slate-800 bg-slate-900/40 p-6 text-slate-400">
        Reading authoritative state…
      </section>
    )
  }

  const backed = state.supportingCapacity >= state.aggregateObligation

  const remaining = commitment.record?.remainingEntitlement

  return (
    <section className="space-y-4">
      <header className="flex items-baseline justify-between">
        <h2 className="text-lg font-semibold text-slate-100">Authoritative state</h2>
        <span className="text-xs text-slate-500">{loading ? 're-reading from chain…' : 'read from chain'}</span>
      </header>

      <div className="grid gap-3 sm:grid-cols-2">
        <Reading
          label="Supporting Capacity S"
          value={formatUsdc(state.supportingCapacity)}
          source="StandbyHook.supportingCapacity()"
          emphasis
        />
        <Reading
          label="Aggregate Capacity Obligation O"
          value={formatUsdc(state.aggregateObligation)}
          source="StandbyHook.aggregateObligation()"
          emphasis
        />
        <Reading
          label="Remaining Entitlement"
          value={remaining === undefined ? 'no commitment' : formatUsdc(remaining)}
          source="StandbyHook.commitment(id).remainingEntitlement"
        />
        <Reading
          label="Beneficiary MockUSDC balance"
          value={formatUsdc(state.beneficiaryBalance)}
          source={`MockUSDC.balanceOf(${shortAddress(state.beneficiary)})`}
        />
      </div>

      <div
        className={`rounded-lg border p-4 ${
          backed ? 'border-emerald-700 bg-emerald-950/40' : 'border-rose-700 bg-rose-950/40'
        }`}
      >
        <div className="text-xs uppercase tracking-wide text-slate-400">Backing relation</div>
        <div className="mt-1 font-mono text-lg text-slate-100">
          {formatUsdc(state.supportingCapacity)} {backed ? '≥' : '<'} {formatUsdc(state.aggregateObligation)}
        </div>
        <div className="mt-1 text-xs text-slate-400">
          {backed
            ? 'Supporting Capacity covers the Aggregate Capacity Obligation.'
            : 'Backing requirement violated — no transition may leave the service here.'}
        </div>
      </div>

      <details className="rounded-lg border border-slate-800 bg-slate-900/40 p-4 text-sm text-slate-400">
        <summary className="cursor-pointer text-slate-300">Secondary evidence</summary>

        <dl className="mt-3 grid gap-2 font-mono text-xs sm:grid-cols-2">
          <div>
            <dt className="text-slate-500">pool tick (PoolManager)</dt>
            <dd className="text-slate-200">{state.slot0.tick}</dd>
          </div>
          <div>
            <dt className="text-slate-500">sqrtPriceX96 (PoolManager)</dt>
            <dd className="break-all text-slate-200">{String(state.slot0.sqrtPriceX96)}</dd>
          </div>
          <div>
            <dt className="text-slate-500">MockUSDC held by StandbyHook</dt>
            <dd className="text-slate-200">{formatUsdc(state.hookCustody)}</dd>
          </div>
          <div>
            <dt className="text-slate-500">MockUSDC held by ExerciseRouter</dt>
            <dd className="text-slate-200">{formatUsdc(state.routerCustody)}</dd>
          </div>
          <div className="sm:col-span-2">
            <dt className="text-slate-500">service id (PoolId)</dt>
            <dd className="break-all text-slate-200">{state.serviceId}</dd>
          </div>
        </dl>

        <p className="mt-3 text-xs text-slate-500">
          Zero Standby token custody supports the non-reservation claim but does not by itself establish it:
          the proof is admission without segregation together with compatible ordinary use of the same
          shared capacity.
        </p>
      </details>
    </section>
  )
}

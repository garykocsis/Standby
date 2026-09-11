import { formatUsdc } from '../lib/format.js'

function ActionButton({ step, title, detail, call, from, onClick, disabled, pending }) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled || Boolean(pending)}
      className="w-full rounded-lg border border-slate-700 bg-slate-900 p-4 text-left transition hover:border-sky-600 hover:bg-slate-800 disabled:cursor-not-allowed disabled:opacity-40"
    >
      <div className="flex items-center justify-between">
        <span className="text-sm font-semibold text-slate-100">
          {step}. {title}
        </span>
        <span className="text-xs text-slate-500">{pending === step ? 'submitting…' : ''}</span>
      </div>
      <div className="mt-1 text-sm text-slate-400">{detail}</div>
      <div className="mt-2 font-mono text-[11px] text-slate-500">
        {call} · sent by {from}
      </div>
    </button>
  )
}

/**
 * The four canonical judged actions.
 *
 * Bootstrap, service activation, eligibility administration, funding, liquidity provisioning, and reset are
 * environment operations and are deliberately not buttons here. The order below is the canonical
 * presentation order; it is not protocol authority, and A3 is demo choreography rather than a prerequisite
 * for A4 — the deployed contracts decide the validity of every one of these calls.
 */
export default function ActionPanel({ config, commitment, actions }) {
  const { parameters } = config

  return (
    <section className="space-y-3">
      <header className="flex items-baseline justify-between">
        <h2 className="text-lg font-semibold text-slate-100">Canonical actions</h2>
        <span className="text-xs text-slate-500">A1 → A2 → A3 → A4</span>
      </header>

      <ActionButton
        step="A1"
        title="Admit Commitment"
        detail={`Admit a future exact-output execution commitment of ${formatUsdc(parameters.commitmentQ)} against the shared pool.`}
        call="StandbyHook.establishCommitment(…)"
        from="establishment authority"
        onClick={actions.admitCommitment}
        pending={actions.pending}
      />

      <ActionButton
        step="A2"
        title="Compatible Ordinary Swap"
        detail={`An unrelated eligible trader draws ${formatUsdc(parameters.compatibleSwapOutput)} of protected output from the same shared liquidity while the commitment is outstanding.`}
        call="ActorAwareTestRouter.swap(…) → PoolManager"
        from="ordinary trader"
        onClick={actions.compatibleOrdinarySwap}
        pending={actions.pending}
      />

      <ActionButton
        step="A3"
        title="Attempt Capacity-Destroying Ordinary Swap"
        detail={`The same trader asks for ${formatUsdc(parameters.destructiveSwapOutput)}, which would leave the outstanding obligation insufficiently backed.`}
        call="ActorAwareTestRouter.swap(…) → PoolManager"
        from="ordinary trader"
        onClick={actions.attemptDestructiveOrdinarySwap}
        pending={actions.pending}
      />

      <ActionButton
        step="A4"
        title="Exercise Commitment"
        detail={
          commitment.record
            ? `Exercise commitment #${String(commitment.id)} in full through actual AMM execution, delivering ${formatUsdc(commitment.record.remainingEntitlement)} to the authoritative Beneficiary.`
            : 'No commitment is referenced by the service yet.'
        }
        call="ExerciseRouter.exercise(…)"
        from="exercise authority"
        onClick={() => actions.exerciseCommitment(commitment)}
        disabled={!commitment.record}
        pending={actions.pending}
      />
    </section>
  )
}

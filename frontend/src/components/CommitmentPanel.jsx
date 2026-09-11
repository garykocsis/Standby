import { formatTimestamp, formatUsdc, shortAddress } from '../lib/format.js'

function Fact({ label, value, title }) {
  return (
    <div>
      <dt className="text-xs uppercase tracking-wide text-slate-500">{label}</dt>
      <dd className="font-mono text-sm text-slate-200" title={title}>
        {value}
      </dd>
    </div>
  )
}

/**
 * The authoritative fact record of the commitment the service currently references.
 *
 * These are persisted facts read back from `StandbyHook.commitment(id)` and nothing else. No validity,
 * exercisability, binding status, or fulfillment is computed here — the Hook derives all of those from
 * these same facts whenever it needs them.
 */
export default function CommitmentPanel({ commitment }) {
  if (!commitment.record) {
    return (
      <section className="rounded-xl border border-slate-800 bg-slate-900/40 p-6">
        <h2 className="text-lg font-semibold text-slate-100">Commitment</h2>
        <p className="mt-2 text-sm text-slate-400">
          No commitment is referenced by the service. Shared executable capacity exists before any Standby
          obligation is admitted.
        </p>
      </section>
    )
  }

  const record = commitment.record

  return (
    <section className="rounded-xl border border-slate-800 bg-slate-900/40 p-6">
      <div className="flex items-baseline justify-between">
        <h2 className="text-lg font-semibold text-slate-100">Commitment #{String(commitment.id)}</h2>
        <span className="font-mono text-xs text-slate-500">StandbyHook.commitment({String(commitment.id)})</span>
      </div>

      <dl className="mt-4 grid gap-3 sm:grid-cols-2">
        <Fact label="Original Entitlement" value={formatUsdc(record.originalEntitlement)} />
        <Fact label="Remaining Entitlement" value={formatUsdc(record.remainingEntitlement)} />
        <Fact label="Beneficiary" value={shortAddress(record.beneficiary)} title={record.beneficiary} />
        <Fact
          label="Exercise authority"
          value={shortAddress(record.exerciseAuthority)}
          title={record.exerciseAuthority}
        />
        <Fact label="Exercisable from" value={formatTimestamp(record.exercisableFrom)} />
        <Fact label="Valid until" value={formatTimestamp(record.validUntil)} />
      </dl>
    </section>
  )
}

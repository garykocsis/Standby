import { isBackingRejection } from '../lib/errors.js'
import { formatUsdc, formatUstb, shortAddress } from '../lib/format.js'

const STATUS_STYLES = {
  PASS: 'border-emerald-700 bg-emerald-950/40 text-emerald-200',
  REJECTED: 'border-amber-600 bg-amber-950/40 text-amber-200',
  FAILED: 'border-rose-700 bg-rose-950/40 text-rose-200',
}

function Block({ title, tone = 'neutral', children }) {
  const tones = {
    neutral: 'border-slate-800 bg-slate-900/60',
    proposed: 'border-slate-700 bg-slate-900',
    prospective: 'border-violet-800 bg-violet-950/30',
  }

  return (
    <div className={`rounded-lg border p-4 ${tones[tone]}`}>
      <div className="text-xs uppercase tracking-wide text-slate-400">{title}</div>
      <div className="mt-2 space-y-1 font-mono text-sm text-slate-200">{children}</div>
    </div>
  )
}

/**
 * The latest action outcome, with its evidence separated by class.
 *
 * Authoritative current state, proposed transaction facts, and prospective derived state are kept visibly
 * apart. A prospective quantity is a prediction the protocol used to decide; it never became state, and it
 * is never presented as if it had. The result itself is the actual receipt or the decoded revert reason,
 * and the state shown after it is a fresh authoritative read rather than an assumption about what the
 * action must have done.
 */
export default function ActionResult({ result }) {
  if (!result) {
    return (
      <section className="rounded-xl border border-slate-800 bg-slate-900/40 p-6 text-sm text-slate-400">
        No action has been performed yet in this session. The state above is read from the chain.
      </section>
    )
  }

  const { action, status, before, after, request, prospectiveCapacity, rejection, delivery, hash } = result

  const destructive = action === 'A3'

  return (
    <section className="space-y-3">
      <header className="flex items-center justify-between">
        <h2 className="text-lg font-semibold text-slate-100">Latest action — {action}</h2>
        <span className={`rounded-full border px-3 py-1 text-xs font-semibold ${STATUS_STYLES[status]}`}>
          {status === 'REJECTED' && isBackingRejection(rejection)
            ? 'REJECTED BY STANDBY BACKING REQUIREMENT'
            : status}
        </span>
      </header>

      {before && (
        <Block title="Authoritative state before">
          <div>S = {formatUsdc(before.supportingCapacity)}</div>
          <div>O = {formatUsdc(before.aggregateObligation)}</div>
        </Block>
      )}

      {request && (
        <Block title="Proposed transaction" tone="proposed">
          {request.protectedOutput !== undefined && (
            <div>ordinary protected exact-output request = {formatUsdc(request.protectedOutput)}</div>
          )}
          {request.entitlement !== undefined && (
            <div>requested Original Entitlement = {formatUsdc(request.entitlement)}</div>
          )}
          {request.extent !== undefined && <div>exercise extent = {formatUsdc(request.extent)}</div>}
          {request.beneficiary && <div>Beneficiary = {shortAddress(request.beneficiary)}</div>}
          {request.maxInput !== undefined && (
            <div className="text-slate-400">exerciser cost bound = {formatUstb(request.maxInput)}</div>
          )}
        </Block>
      )}

      {prospectiveCapacity !== undefined && before && (
        <Block title="Prospective derived state — production preview, never authoritative" tone="prospective">
          <div>S′ = {formatUsdc(prospectiveCapacity)}</div>
          <div>O = {formatUsdc(before.aggregateObligation)}</div>
          <div className={prospectiveCapacity < before.aggregateObligation ? 'text-amber-300' : 'text-emerald-300'}>
            {formatUsdc(prospectiveCapacity)} {prospectiveCapacity < before.aggregateObligation ? '<' : '≥'}{' '}
            {formatUsdc(before.aggregateObligation)}
          </div>
          <div className="text-xs text-slate-400">
            StandbyHook.prospectiveSupportingCapacityAfterSwap(…) — the same derivation enforcement uses.
          </div>
        </Block>
      )}

      {rejection && (
        <Block title="Rejection reason, decoded from the revert">
          <div className="break-all text-amber-200">{rejection.message}</div>
          {isBackingRejection(rejection) ? (
            <div className="text-xs text-slate-400">
              The transition was refused because its prospective Supporting Capacity would not cover the
              outstanding Capacity Obligation — not for eligibility, balance, allowance, slippage, the
              service domain, or an unrelated Uniswap failure.
            </div>
          ) : (
            <div className="text-xs text-slate-400">
              This is not the Standby backing rejection. It is reported exactly as the contracts gave it.
            </div>
          )}
        </Block>
      )}

      {delivery && (
        <Block title="Beneficiary delivery, from authoritative token balances">
          <div>before = {formatUsdc(delivery.before)}</div>
          <div>after = {formatUsdc(delivery.after)}</div>
          <div className="text-emerald-300">delivered = {formatUsdc(delivery.delta)}</div>
        </Block>
      )}

      {after && (
        <Block title={destructive ? 'Authoritative state after the revert — re-read from chain' : 'Authoritative state after — re-read from chain'}>
          <div>S = {formatUsdc(after.supportingCapacity)}</div>
          <div>O = {formatUsdc(after.aggregateObligation)}</div>
          {destructive && (
            <div className="text-xs text-slate-400">
              The prospective quantity above never became authoritative state.
            </div>
          )}
        </Block>
      )}

      {hash && (
        <div className="font-mono text-[11px] text-slate-500">
          transaction <span className="break-all text-slate-400">{hash}</span>
        </div>
      )}
    </section>
  )
}

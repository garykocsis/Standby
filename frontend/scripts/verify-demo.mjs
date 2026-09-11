/**
 * Frontend verification: drives the four canonical judged actions through the exact modules the interface
 * uses, against a running deterministic Anvil environment, and checks the canonical economic history.
 *
 * This is a check on the interface's own code, not a second demonstration path. It imports
 * `src/lib/standby.js`, `src/lib/rpc.js`, `src/lib/errors.js` and `src/lib/contracts.js` unchanged, so what
 * it exercises is what a button press exercises: the same production calls, the same authoritative reads,
 * the same rejection decoding. It renders nothing and asserts nothing about the protocol that the protocol
 * does not report itself.
 *
 * It assumes the environment produced by `./script/demo/run-demo-environment.sh` and consumes it: after a
 * successful run the service stands at the terminal canonical state, so re-run the runner against a fresh
 * Anvil before using the interface.
 *
 *   cd frontend && npm run verify:demo
 */
import { readFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'

import { parseDemoManifest } from '../src/lib/contracts.js'
import { isBackingRejection } from '../src/lib/errors.js'
import { createClients } from '../src/lib/rpc.js'
import {
  admitCommitment,
  exerciseCommitment,
  ordinarySwap,
  readCommitment,
  readStandbyState,
} from '../src/lib/standby.js'

const MANIFEST_PATH = fileURLToPath(new URL('../public/standby-demo.json', import.meta.url))

const failures = []

function check(description, condition, detail) {
  const status = condition ? 'ok  ' : 'FAIL'

  console.log(`  [${status}] ${description}${detail === undefined ? '' : ` — ${detail}`}`)

  if (!condition) failures.push(description)
}

const usdc = (amount) => `${(Number(amount) / 1e6).toLocaleString('en-US')} MockUSDC`

const manifest = parseDemoManifest(JSON.parse(await readFile(MANIFEST_PATH, 'utf8')), process.env.RPC_URL)

const clients = createClients(manifest)
const { parameters } = manifest

console.log(`Standby frontend verification against ${manifest.rpcUrl} (chain ${manifest.chainId})\n`)

console.log('Bootstrap — the canonical pre-A1 state')
{
  const state = await readStandbyState(clients, manifest, manifest.actors.beneficiary)
  const commitment = await readCommitment(clients, manifest)

  check('authoritative reads resolve', state.serviceId !== undefined)
  check('S = 80,000', state.supportingCapacity === 80_000_000_000n, usdc(state.supportingCapacity))
  check('O = 0', state.aggregateObligation === 0n, usdc(state.aggregateObligation))
  check('no commitment is referenced', commitment.record === null)
  check('pool tick is authoritative', Number.isInteger(state.slot0.tick), `tick ${state.slot0.tick}`)
  check('Standby holds no protected output', state.hookCustody === 0n && state.routerCustody === 0n)
}

console.log('\nA1 — admit the 50,000 MockUSDC commitment')
{
  const result = await admitCommitment(clients, manifest)

  check('the admission transaction succeeded', result.status === 'PASS', result.hash)
  check('S is unchanged at 80,000', result.after.supportingCapacity === 80_000_000_000n, usdc(result.after.supportingCapacity))
  check('O became 50,000', result.after.aggregateObligation === 50_000_000_000n, usdc(result.after.aggregateObligation))

  const commitment = await readCommitment(clients, manifest)

  check('the commitment is referenced by the service', commitment.record !== null, `#${commitment.id}`)
  check(
    'Remaining Entitlement = 50,000',
    commitment.record?.remainingEntitlement === 50_000_000_000n,
    usdc(commitment.record?.remainingEntitlement),
  )
}

const service = (await readStandbyState(clients, manifest, manifest.actors.beneficiary)).service

console.log('\nA2 — the compatible ordinary swap of 15,000 MockUSDC')
{
  const result = await ordinarySwap(clients, manifest, {
    action: 'A2',
    service,
    amountOut: parameters.compatibleSwapOutput,
  })

  check('the production preview predicted S′ = 65,000', result.prospectiveCapacity === 65_000_000_000n, usdc(result.prospectiveCapacity))
  check('the ordinary swap succeeded while the obligation was outstanding', result.status === 'PASS', result.hash)
  check('S = 65,000', result.after.supportingCapacity === 65_000_000_000n, usdc(result.after.supportingCapacity))
  check('O is still 50,000', result.after.aggregateObligation === 50_000_000_000n, usdc(result.after.aggregateObligation))

  const commitment = await readCommitment(clients, manifest)

  check(
    'an ordinary swap did not reduce Remaining Entitlement',
    commitment.record?.remainingEntitlement === 50_000_000_000n,
    usdc(commitment.record?.remainingEntitlement),
  )
}

console.log('\nA3 — the capacity-destroying ordinary attempt of 20,000 MockUSDC')
{
  const result = await ordinarySwap(clients, manifest, {
    action: 'A3',
    service,
    amountOut: parameters.destructiveSwapOutput,
  })

  check('the production preview predicted S′ = 45,000', result.prospectiveCapacity === 45_000_000_000n, usdc(result.prospectiveCapacity))
  check('45,000 < 50,000', result.prospectiveCapacity < result.before.aggregateObligation)
  check('the transition was refused', result.status === 'REJECTED', result.hash)
  check('the refusal is the Standby backing rejection', isBackingRejection(result.rejection), result.rejection?.message)
  check(
    'the rejection names the two quantities the Hook compared',
    result.rejection?.args?.[0] === 45_000_000_000n && result.rejection?.args?.[1] === 50_000_000_000n,
  )
  check('authoritative S remained 65,000', result.after.supportingCapacity === 65_000_000_000n, usdc(result.after.supportingCapacity))
  check('authoritative O remained 50,000', result.after.aggregateObligation === 50_000_000_000n, usdc(result.after.aggregateObligation))

  const commitment = await readCommitment(clients, manifest)

  check(
    'Remaining Entitlement remained 50,000',
    commitment.record?.remainingEntitlement === 50_000_000_000n,
    usdc(commitment.record?.remainingEntitlement),
  )
}

console.log('\nA4 — the full exercise of the admitted commitment')
{
  const commitment = await readCommitment(clients, manifest)

  const result = await exerciseCommitment(clients, manifest, commitment)

  check('the exercise transaction succeeded', result.status === 'PASS', result.hash)
  check(
    'the Beneficiary received exactly 50,000',
    result.delivery.delta === 50_000_000_000n,
    usdc(result.delivery.delta),
  )
  check('S = 15,000', result.after.supportingCapacity === 15_000_000_000n, usdc(result.after.supportingCapacity))
  check('O = 0', result.after.aggregateObligation === 0n, usdc(result.after.aggregateObligation))

  const state = await readStandbyState(clients, manifest, commitment.record.beneficiary)
  const fulfilled = await readCommitment(clients, manifest)

  check('Remaining Entitlement = 0', fulfilled.record?.remainingEntitlement === 0n)
  check('the same commitment A1 created was exercised', fulfilled.id === commitment.id, `#${fulfilled.id}`)
  check('Standby holds no protected output', state.hookCustody === 0n && state.routerCustody === 0n)
  check(
    'the Beneficiary balance is authoritative',
    state.beneficiaryBalance === 50_000_000_000n,
    usdc(state.beneficiaryBalance),
  )
}

console.log('\nRe-read — every value above, read again from the chain alone')
{
  const commitment = await readCommitment(clients, manifest)
  const state = await readStandbyState(clients, manifest, commitment.record.beneficiary)

  check('S = 15,000', state.supportingCapacity === 15_000_000_000n, usdc(state.supportingCapacity))
  check('O = 0', state.aggregateObligation === 0n, usdc(state.aggregateObligation))
  check('Remaining Entitlement = 0', commitment.record.remainingEntitlement === 0n)
  check('Beneficiary MockUSDC = 50,000', state.beneficiaryBalance === 50_000_000_000n, usdc(state.beneficiaryBalance))
}

console.log(
  failures.length === 0
    ? '\nAll canonical checks passed.'
    : `\n${failures.length} check(s) failed:\n  ${failures.join('\n  ')}`,
)

process.exit(failures.length === 0 ? 0 : 1)

import { encodeFunctionData } from 'viem'

import {
  actorAwareTestRouterAbi,
  exerciseRouterAbi,
  mockUsdcAbi,
  readPoolSlot0,
  standbyHookAbi,
} from './contracts.js'
import { decodeRejection } from './errors.js'

/**
 * The Standby protocol surface the demonstration reads and acts through.
 *
 * Everything economically meaningful in this module is a call to a deployed contract. Nothing here derives
 * Supporting Capacity, Aggregate Capacity Obligation, Remaining Entitlement, prospective capacity, backing
 * validity, fulfillment, or authorization: those are the Hook's, and this module asks it.
 *
 * What this module does own is proposals — the quantities a judge asks Standby for, the commitment window,
 * and the shape of the ordinary swap — and reporting what the chain did with them. Both are kept separate
 * from authoritative state at every call site.
 *
 * It is deliberately free of React so that the interface and the headless verification command drive the
 * same code against the same chain.
 */

/// The two quantities every stage of the canonical sequence is judged on.
export async function readAuthoritative(clients, config) {
  const hook = { address: config.addresses.hook, abi: standbyHookAbi }

  const [supportingCapacity, aggregateObligation] = await Promise.all([
    clients.publicClient.readContract({ ...hook, functionName: 'supportingCapacity' }),
    clients.publicClient.readContract({ ...hook, functionName: 'aggregateObligation' }),
  ])

  return { supportingCapacity, aggregateObligation }
}

/**
 * Reads the commitment the service currently references.
 *
 * The bounded enforcement-reference index is the Hook's own record of which commitments later derivation
 * may need to inspect, so the interface asks it which commitment exists rather than remembering the one it
 * saw created. Choosing which record to display is not a derivation: every field returned is a persisted
 * fact read straight back from the Hook.
 */
export async function readCommitment(clients, config) {
  const hook = { address: config.addresses.hook, abi: standbyHookAbi }

  const references = await clients.publicClient.readContract({ ...hook, functionName: 'enforcementReferences' })

  const referenced = references.find((identity) => identity !== 0n)

  if (referenced === undefined) return { id: null, record: null }

  const record = await clients.publicClient.readContract({
    ...hook,
    functionName: 'commitment',
    args: [referenced],
  })

  return { id: referenced, record }
}

/** Reads the complete authoritative state the interface displays. */
export async function readStandbyState(clients, config, beneficiary) {
  const { publicClient } = clients
  const { hook, usdc, poolManager, exerciseRouter } = config.addresses

  const hookContract = { address: hook, abi: standbyHookAbi }
  const balanceOf = (holder) =>
    publicClient.readContract({ address: usdc, abi: mockUsdcAbi, functionName: 'balanceOf', args: [holder] })

  const [service, serviceId, supportingCapacity, aggregateObligation, nextCommitmentId] = await Promise.all([
    publicClient.readContract({ ...hookContract, functionName: 'protectedExecutionService' }),
    publicClient.readContract({ ...hookContract, functionName: 'serviceId' }),
    publicClient.readContract({ ...hookContract, functionName: 'supportingCapacity' }),
    publicClient.readContract({ ...hookContract, functionName: 'aggregateObligation' }),
    publicClient.readContract({ ...hookContract, functionName: 'nextCommitmentId' }),
  ])

  const [slot0, beneficiaryBalance, hookCustody, routerCustody] = await Promise.all([
    readPoolSlot0(publicClient, poolManager, serviceId),
    balanceOf(beneficiary),
    balanceOf(hook),
    balanceOf(exerciseRouter),
  ])

  return {
    service,
    serviceId,
    supportingCapacity,
    aggregateObligation,
    nextCommitmentId,
    slot0,
    beneficiary,
    beneficiaryBalance,
    hookCustody,
    routerCustody,
  }
}

/**
 * Submits one transaction and reports what the chain did with it.
 *
 * A refused transition is a real submission the protocol refused, so it is sent rather than only simulated.
 * When the receipt comes back reverted, the same call is replayed against the block before it to recover
 * the revert data a receipt does not carry, and that data is decoded into the reason the contracts gave.
 */
async function submit(clients, { account, address, abi, functionName, args }) {
  const hash = await clients.walletClientFor(account).writeContract({ address, abi, functionName, args })

  const receipt = await clients.publicClient.waitForTransactionReceipt({ hash })

  if (receipt.status === 'success') return { hash, receipt, rejection: null }

  let rejection = { name: null, args: [], message: 'The transaction reverted.' }

  try {
    await clients.publicClient.call({
      account,
      to: address,
      data: encodeFunctionData({ abi, functionName, args }),
      blockNumber: receipt.blockNumber - 1n,
    })
  } catch (error) {
    rejection = decodeRejection(error)
  }

  return { hash, receipt, rejection }
}

/**
 * A1 — admit the canonical future exact-output execution commitment.
 *
 * Sent by the service's own establishment authority. Admission establishes an obligation without consuming
 * capacity and without segregating any MockUSDC; both are visible in the state read back afterwards.
 */
export async function admitCommitment(clients, config) {
  const { addresses, actors, parameters } = config

  const before = await readAuthoritative(clients, config)

  const block = await clients.publicClient.getBlock()

  const request = {
    beneficiary: actors.beneficiary,
    exerciseAuthority: actors.exerciseAuthority,
    entitlement: parameters.commitmentQ,
    exercisableFrom: block.timestamp,
    validUntil: block.timestamp + parameters.validityDuration,
  }

  const { hash, receipt, rejection } = await submit(clients, {
    account: actors.establishmentAuthority,
    address: addresses.hook,
    abi: standbyHookAbi,
    functionName: 'establishCommitment',
    args: [
      request.beneficiary,
      request.exerciseAuthority,
      request.entitlement,
      request.exercisableFrom,
      request.validUntil,
    ],
  })

  return {
    action: 'A1',
    status: rejection ? 'REJECTED' : 'PASS',
    hash,
    receipt,
    rejection,
    request,
    before,
    after: await readAuthoritative(clients, config),
  }
}

/**
 * A2 and A3 — the ordinary protected exact-output swap, through the trusted perimeter as the eligible
 * trader.
 *
 * The two stages are the same call with different quantities, which is the point: one is compatible with
 * the outstanding obligation and one destroys the backing it requires, and only the protocol decides which.
 * The direction and pool come from the Hook's own activated service basis, and the price limit is the
 * service's protected execution-quality boundary as pinned Solidity reported it — so a refusal stays
 * attributable to backing rather than to a service-domain violation.
 */
export async function ordinarySwap(clients, config, { action, service, amountOut }) {
  const { addresses, actors, parameters } = config

  const before = await readAuthoritative(clients, config)

  const params = {
    zeroForOne: service.protectedZeroForOne,
    amountSpecified: amountOut,
    sqrtPriceLimitX96: parameters.sqrtPriceLimitX96,
  }

  const prospectiveCapacity = await clients.publicClient.readContract({
    address: addresses.hook,
    abi: standbyHookAbi,
    functionName: 'prospectiveSupportingCapacityAfterSwap',
    args: [params],
  })

  const { hash, receipt, rejection } = await submit(clients, {
    account: actors.trader,
    address: addresses.swapPerimeter,
    abi: actorAwareTestRouterAbi,
    functionName: 'swap',
    args: [service.poolKey, params, '0x'],
  })

  return {
    action,
    status: rejection ? 'REJECTED' : 'PASS',
    hash,
    receipt,
    rejection,
    request: { protectedOutput: amountOut, params },
    prospectiveCapacity,
    before,
    after: await readAuthoritative(clients, config),
  }
}

/**
 * A4 — exercise a commitment in full through the production ExerciseRouter / O2 path.
 *
 * The extent is the commitment's own authoritative Remaining Entitlement, the sender is the commitment's
 * own exercise authority, and the delivery is measured as the increase in the authoritative Beneficiary's
 * MockUSDC balance rather than inferred from the transaction having succeeded.
 */
export async function exerciseCommitment(clients, config, commitment) {
  const { addresses, parameters } = config

  const before = await readAuthoritative(clients, config)

  const balanceOf = (holder) =>
    clients.publicClient.readContract({
      address: addresses.usdc,
      abi: mockUsdcAbi,
      functionName: 'balanceOf',
      args: [holder],
    })

  const beneficiaryBefore = await balanceOf(commitment.record.beneficiary)

  const request = {
    commitmentId: commitment.id,
    extent: commitment.record.remainingEntitlement,
    maxInput: parameters.exerciseMaxInput,
    beneficiary: commitment.record.beneficiary,
  }

  const { hash, receipt, rejection } = await submit(clients, {
    account: commitment.record.exerciseAuthority,
    address: addresses.exerciseRouter,
    abi: exerciseRouterAbi,
    functionName: 'exercise',
    args: [request.commitmentId, request.extent, request.maxInput],
  })

  const beneficiaryAfter = await balanceOf(commitment.record.beneficiary)

  return {
    action: 'A4',
    status: rejection ? 'REJECTED' : 'PASS',
    hash,
    receipt,
    rejection,
    request,
    before,
    after: await readAuthoritative(clients, config),
    delivery: { before: beneficiaryBefore, after: beneficiaryAfter, delta: beneficiaryAfter - beneficiaryBefore },
  }
}

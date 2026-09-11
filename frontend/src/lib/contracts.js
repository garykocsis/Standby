import { concat, keccak256, pad, toHex } from 'viem'

import { poolManagerAbi } from './abis.js'

export {
  actorAwareTestRouterAbi,
  exerciseRouterAbi,
  mockUsdcAbi,
  poolManagerAbi,
  standbyHookAbi,
} from './abis.js'

/// The index of the `pools` mapping in the PoolManager, as the pinned `StateLibrary` defines it. The pool
/// state read below is a storage read of authoritative PoolManager state, not a derivation of one.
const POOLS_SLOT = 6

/// Where the demo runner writes the deployed manifest.
const MANIFEST_URL = '/standby-demo.json'

/**
 * Reads the deployed demo manifest: contract addresses, role accounts, and the canonical
 * proposed-transaction parameters.
 *
 * The manifest is configuration, never economic state. It records which contracts exist and which account
 * holds which role; every economic fact about the system those addresses form is read from the chain.
 */
export function parseDemoManifest(manifest, rpcOverride) {
  return {
    chainId: manifest.chainId,
    rpcUrl: rpcOverride ?? manifest.rpcUrl,
    addresses: manifest.addresses,
    actors: manifest.actors,
    parameters: {
      sqrtPriceLimitX96: BigInt(manifest.parameters.sqrtPriceLimitX96),
      commitmentQ: BigInt(manifest.parameters.commitmentQ),
      compatibleSwapOutput: BigInt(manifest.parameters.compatibleSwapOutput),
      destructiveSwapOutput: BigInt(manifest.parameters.destructiveSwapOutput),
      exerciseMaxInput: BigInt(manifest.parameters.exerciseMaxInput),
      validityDuration: BigInt(manifest.parameters.validityDuration),
      protectedZeroForOne: manifest.parameters.protectedZeroForOne,
    },
  }
}

/** Loads the deployed demo manifest the runner wrote for this environment. */
export async function loadDemoConfig() {
  const response = await fetch(MANIFEST_URL)

  if (!response.ok) {
    throw new Error(
      `No demo manifest at ${MANIFEST_URL}. Run ./script/demo/run-demo-environment.sh against a local Anvil node first.`,
    )
  }

  return parseDemoManifest(await response.json(), import.meta.env?.VITE_RPC_URL)
}

/**
 * Reads the authoritative price and tick of a pool straight out of PoolManager storage.
 *
 * This is the same `pools[poolId].slot0` word the pinned `StateLibrary` reads through `extsload`, decoded
 * as that library decodes it. Pool price and tick are secondary explanatory evidence; no Standby economic
 * quantity is computed from them here.
 */
export async function readPoolSlot0(publicClient, poolManager, poolId) {
  const stateSlot = keccak256(concat([poolId, pad(toHex(POOLS_SLOT), { size: 32 })]))

  const word = await publicClient.readContract({
    address: poolManager,
    abi: poolManagerAbi,
    functionName: 'extsload',
    args: [stateSlot],
  })

  const value = BigInt(word)

  const sqrtPriceX96 = value & ((1n << 160n) - 1n)
  const rawTick = (value >> 160n) & 0xffffffn

  return {
    sqrtPriceX96,
    tick: Number(rawTick >= 0x800000n ? rawTick - 0x1000000n : rawTick),
  }
}

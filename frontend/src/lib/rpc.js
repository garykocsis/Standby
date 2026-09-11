import { createPublicClient, createWalletClient, defineChain, http } from 'viem'

/**
 * Builds the clients the interface reads and acts through.
 *
 * Actions are sent from the account the protocol itself requires — the service's establishment authority,
 * the eligible trader, the commitment's exercise authority — as unlocked accounts on the deterministic
 * local node. Role separation is therefore visible in the demonstration rather than collapsed into one
 * signer, and no account acquires authority by being used here: every one of these calls is refused unless
 * the deployed contracts themselves authorize it.
 */
export function createClients(config) {
  const chain = defineChain({
    id: config.chainId,
    name: 'Standby deterministic local',
    nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
    rpcUrls: { default: { http: [config.rpcUrl] } },
  })

  const transport = http(config.rpcUrl)

  return {
    chain,
    publicClient: createPublicClient({ chain, transport }),
    walletClientFor: (account) => createWalletClient({ account, chain, transport }),
  }
}

# Standby demo frontend

Judge-facing instrumentation for the canonical Standby demonstration. See the [root README](../README.md)
for what the demonstration proves and how to run it end to end.

This is instrumentation, not a dApp and not a second state machine. It holds no economic state: after every
action it waits for the receipt or the revert, re-reads authoritative state from the chain, and renders what
it read. A full page reload reconstructs authoritative economic state from the chain; proposed demo
transaction facts are loaded separately from the generated canonical demo manifest.

## Prerequisites

1. `forge build` has been run at the repository root — the ABIs here are imported from `../out`. The
   interface uses ABI definitions from the same Foundry build artifacts used by the canonical deployment,
   avoiding a separately maintained ABI that could drift from the deployed contracts.
2. A local Anvil node is running.
3. `./script/demo/run-demo-environment.sh` has been run against it. That writes
   `public/standby-demo.json`, the deployed manifest this app reads.

## Commands

```bash
npm ci                 # install from the lockfile
npm run dev            # http://localhost:5173
npm run build          # production build
npm run lint           # eslint
npm run verify:demo    # drive A1–A4 headlessly against the running chain
```

`npm run verify:demo` imports `src/lib/standby.js`, `src/lib/rpc.js`, `src/lib/errors.js` and
`src/lib/contracts.js` unchanged and performs the four canonical actions through them, checking the full
canonical history — 80k/0 → 80k/50k/50k → 65k/50k/50k → prospective 45k rejected with the specific Standby
backing error and unchanged authoritative state → 15k/0/0 with exactly +50,000 MockUSDC delivered. It is a
check on this app's own code against a real chain, not a second demonstration path.

It consumes the environment it runs against: afterwards the service stands at the terminal state, so restart
Anvil and re-run the demo runner before using the interface.

`VITE_RPC_URL` overrides the RPC endpoint in the manifest.

## Layout

```text
src/
├── components/     StandbyStatePanel · CommitmentPanel · ActionPanel · ActionResult
├── hooks/          useStandbyState · useCommitment · useDemoActions   (React state only)
└── lib/
    ├── abis.js       ABIs, imported from the Foundry build output
    ├── contracts.js  manifest parsing and the PoolManager slot0 read
    ├── standby.js    the production calls: the authoritative reads and the four canonical actions
    ├── rpc.js        viem clients; each action is sent by the account the protocol requires
    ├── errors.js     ERC-7751 unwrapping and custom-error decoding
    └── format.js     display formatting
```

`lib/standby.js` deliberately contains no React, so the interface and the headless verification command
drive the same code.

## Authoritative read map

| Displayed fact           | Source                                                               |
| ------------------------ | -------------------------------------------------------------------- |
| Supporting Capacity `S`  | `StandbyHook.supportingCapacity()`                                   |
| Aggregate Obligation `O` | `StandbyHook.aggregateObligation()`                                  |
| Remaining Entitlement    | `StandbyHook.commitment(id).remainingEntitlement`                    |
| Commitment facts         | `StandbyHook.commitment(id)`, indexed by `enforcementReferences()`   |
| Beneficiary balance      | `MockUSDC.balanceOf(commitment.beneficiary)`                         |
| Service basis / PoolKey  | `StandbyHook.protectedExecutionService()` / `serviceId()`            |
| Pool price and tick      | `PoolManager` storage (`pools[poolId].slot0`, via `extsload`)        |
| Prospective `S′`         | `StandbyHook.prospectiveSupportingCapacityAfterSwap(params)`         |
| Action outcome / reason  | the actual receipt, or the decoded revert data of the attempted call |

Nothing in that table is computed here. The interface formats authoritative values and displays the
`S >= O` relation between two of them; the protocol enforces that relation against its own derivation
regardless of what is on screen.

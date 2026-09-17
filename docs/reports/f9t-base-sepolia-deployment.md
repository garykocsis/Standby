# F9T — Base Sepolia Public Testnet Deployment Evidence

**Status of this document:** supplementary post-submission implementation evidence, recorded by the Session 21
Claude implementation. It is not a normative specification, it closes no gate, and it has not been independently
reviewed. G9T PASS/FAIL is determined by independent review.

> **Canonical judged acceptance: deterministic local Anvil.**
> **Supplementary post-submission evidence: Base Sepolia.**

Base Sepolia was not part of the judged canonical environment. This deployment shows that the already accepted
Standby mechanism can be realized against a current public Uniswap v4 testnet stack and reproduce the
protected-capacity lifecycle outside the deterministic local environment. It does **not** establish production or
mainnet readiness, audited status, arbitrary or fixed-price execution guarantees, zero price impact, custody, escrow,
segregated liquidity, capacity pricing, fee-model viability, production permissioning policy, customer adoption, or
institutional deployment.

No Standby economic semantics, production contract, canonical script, fixture value, Hook permission, or pinned
dependency was changed to produce this evidence.

---

## 1. Network and external infrastructure

| Item              | Value                                        |
| ----------------- | -------------------------------------------- |
| Network           | Base Sepolia                                 |
| Chain id          | `84532`                                      |
| PoolManager       | `0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408` |
| Universal Router  | `0x492E6456D9528771018DeB9E87ef7750EF184104` |
| PositionManager   | `0x4B2C77d209D3405F41a037Ec6c77F7F5b8e2ca80` |
| Permit2           | `0x000000000022D473030F116dDEE9F6B43aC78BA3` |
| StateView         | `0x571291b572ed32ce6751a2Cb2486EbEe8DEfB9B4` |
| V4 Quoter         | `0x4A6513c898fe1B2d0E78d3b0e0A4a151589B1cBa` |
| CREATE2 factory   | `0x4e59b44847b379578588920cA78FbF26c0B4956C` |

### Provenance and preflight (live chain, block 46835306 and again inside every script run)

| Check                                           | Result                                       |
| ----------------------------------------------- | -------------------------------------------- |
| chain id                                        | 84532                                        |
| bytecode present at all six frozen addresses    | yes (24009 / 19540 / 23877 / 9152 / 3531 / 5820 bytes) |
| `UniversalRouter.poolManager()`                 | `0x05E7…3408` — matches                      |
| `UniversalRouter.V4_POSITION_MANAGER()`         | `0x4B2C…ca80` — matches                      |
| `PositionManager.poolManager()`                 | `0x05E7…3408` — matches                      |
| `PositionManager.permit2()`                     | `0x0000…8BA3` — matches                      |
| `UniversalRouter.msgSender()` / `PositionManager.msgSender()` | present (zero while idle)      |

Rejected / not introduced:

| Router                                       | `poolManager()`                              | Disposition                     |
| -------------------------------------------- | -------------------------------------------- | ------------------------------- |
| `0x95273d871c8156636e114b63797d78D7E1720d81` | `0x7Da1D65F8B249183667cdE74C5CBD46dD38AA829` | historical stack — rejected     |
| `0x8B844f885672f333Bc0042cB669255f93a4C1E6b` | `0xf7F5aB3DcA35e17dE187b459159BC643853B3c67` | different stack — not introduced |

The preflight is implemented in `script/helpers/HelperConfig.s.sol` (`validateBaseSepoliaInfrastructure`) and runs
before every F9T deployment, bootstrap, action, and verification script resolves infrastructure.

### Deployed Universal Router ABI

The deployed Universal Router's V4 router predates pinned v4-periphery `07336f2`: its bytecode contains none of the
errors introduced with `ExactOutputSingleParams.minHopPriceX36`. Its exact-output single swap parameters are the
earlier five-field layout `{poolKey, zeroForOne, amountOut, amountInMaximum, hookData}`. The F9T scripts encode that
layout through a narrow calldata adapter (`script/helpers/PublicPeriphery.sol`); no dependency was upgraded. The
live A2 swap and the exact A3 revert below confirm the encoding against the deployed bytecode.

### Pinned dependency baseline (unchanged)

| Dependency        | Revision                                   |
| ----------------- | ------------------------------------------ |
| `v4-hooks-public` | `0f731d5de0f4fd60b506b55754d5e6ff086eab7d` |
| `v4-core`         | `d153b048868a60c2403a3ef5b2301bb247884d46` |
| `v4-periphery`    | `07336f2144f522874e2c3c85e04d1d3f8d5fa471` |

---

## 2. Standby-owned deployment

Deployer: `0x193D1F3E085efc80e1027891FaA770E81ECC4A1d` (nonce 0 before deployment).

| Contract                     | Address                                      | Deployment tx                                                        | Block    | Source verification   |
| ---------------------------- | -------------------------------------------- | -------------------------------------------------------------------- | -------- | --------------------- |
| DeterministicFixtureDeployer | `0xc0e6b70c8ff75962541183fdc247e7b07ad6b70b` | `0x9750b0942f66b0cbeaf546a840e070d1cf8831da8974307f4b6a118ed34083c8` | 46836418 | Pass — Verified       |
| MockUSTB (`currency0`)       | `0x6334956A63F676eFc4f44cC330AA0F0546d4F6c8` | `0x263a8d0e2632ea8e057ff05385254ee45e46cd3656ae462d7b856a9c9e9c8abd` (`deployOrderedFixtureCurrencies`) | 46836419 | Pass — Verified |
| MockUSDC (`currency1`)       | `0xeC64E378231542Fdd2Eedf2a1763a041C2Dda523` | same transaction as MockUSTB                                         | 46836419 | Pass — Verified       |
| EligibilityRegistry          | `0x0BffBD010510e7551581F94bF67A621F1Af2fcB6` | `0x1b8f789cceb24262550d755c62ae45f160a84c88faa62037385f3918c502066c` | 46836420 | Pass — Verified       |
| StandbyHook                  | `0x92E89Da9FE8A103f4864914b268Ec364f6458AC0` | `0x89c3d2014ce874c3ac69320d6521f167aca038f6491aaa62430ec1f8c26f9361` (CREATE2 factory) | 46836421 | Pass — Verified |
| ExerciseRouter               | `0x17C3Ff4a5DD943359699d44BF14058cE4f31C187` | `0x844f113130efb7c2b888ade2bddeddd6533caddf517aafedef7a9a7f2c433c14` | 46836422 | Pass — Verified       |

All deployment receipts: status `0x1`. Source verification used `forge verify-contract --chain 84532` against the
Etherscan-compatible Base Sepolia explorer.

On-chain deployment facts (read after deployment):

| Fact                                         | Value                                        |
| -------------------------------------------- | -------------------------------------------- |
| MockUSTB / MockUSDC decimals                 | 6 / 6                                        |
| `address(MockUSTB) < address(MockUSDC)`      | true                                         |
| Hook address permission bits (`& 0x3FFF`)    | `0x0AC0` (beforeAddLiquidity, beforeRemoveLiquidity, beforeSwap, afterSwap) |
| `hook.poolManager()`                         | `0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408` |
| `hook.i_trustedUniversalRouter()`            | `0x492E6456D9528771018DeB9E87ef7750EF184104` (official Universal Router) |
| `hook.i_trustedPositionManager()`            | `0x4B2C77d209D3405F41a037Ec6c77F7F5b8e2ca80` (official PositionManager) |
| `hook.i_configurationAuthority()`            | `0xF6eccecDF284f9f9d2AD3C89378Ce48D235186E7` |
| `exerciseRouter.i_hook()` / `i_poolManager()` | Hook / PoolManager                          |
| `registry.i_admin()`                         | `0x2100336F23d987A8EB733c4fd708350dDC114E4f` |

The Hook was deployed by the canonical `StandbyHookDeployment.deployStandbyHook` procedure (pinned `HookMiner`,
salted creation through the CREATE2 factory, canonical permission / PoolManager / trust-binding validation). No
`ActorAwareTestRouter` was deployed or used.

### Role accounts

Each role is a distinct account whose key is derived in-script from the funded deployment key under the domain
`keccak256("standby.f9t.base-sepolia.role")`. No key is recorded anywhere.

| Role                    | Address                                      |
| ----------------------- | -------------------------------------------- |
| configuration authority | `0xF6eccecDF284f9f9d2AD3C89378Ce48D235186E7` |
| establishment authority | `0x7430643D3988b41D414E34cFB13eb9c851513B78` |
| registry administrator  | `0x2100336F23d987A8EB733c4fd708350dDC114E4f` |
| liquidity provider      | `0x84041400eC3dE315D97948e09aBedFEEc199cd79` |
| trader                  | `0xfCB6999229390D944e074a32f2137d3aBD20e39d` |
| beneficiary             | `0xA3E827bDd2A64574393D243Ead5508E3b792900f` |
| exercise authority      | `0xACd284A9BE5A8eA9A49d3A25eDCBD2d616bb9CC4` |

---

## 3. Canonical pool and service

| Fact              | Value                                                                |
| ----------------- | -------------------------------------------------------------------- |
| PoolKey           | `(MockUSTB, MockUSDC, fee 500, tickSpacing 10, hooks StandbyHook)`   |
| PoolId            | `0x8b6033124249c0b22872e95746f9526d7c722dddedbc7209424923879ca9d271` |
| `hook.serviceId()` | same PoolId                                                         |
| Initial price     | `sqrtPriceX96 = 79228162514264337593543950336` (tick 0)              |
| Protected direction | zeroForOne (MockUSTB → MockUSDC)                                   |
| `tickQ` / `tickO` | −240 / +240                                                          |
| ExerciseRouter    | `0x17C3Ff4a5DD943359699d44BF14058cE4f31C187`                         |
| Establishment authority | `0x7430643D3988b41D414E34cFB13eb9c851513B78`                   |
| Canonical position | range [−300, +300], liquidity 6,707,079,990,254, PositionManager token id 28027, owner = liquidity provider |

---

## 4. Bootstrap transactions (all status `0x1`, blocks 46836492–46836510)

| Step | Sender | Call | Tx |
| ---- | ------ | ---- | -- |
| gas top-up ×6 (0.002 ETH each) | deployer | — | `0xf991d31d61cad2a4df8684e0fcd736a3d85c9ddfff38040f8e2b729026baf553`, `0xf8c20efb8c3c81c3fd0d5ae14f863ac9f30a684e9d37dec9ca4dc42585421ef4`, `0x785a204b8b2b5693523b213aa96f9d2bd2314294cccbf7144619db810d14f9e0`, `0x8f474496d2f68aa4ccf7c7171809b9dfafa3f716ca4ba9985c4c45118be877d9`, `0x56eb1a8657b6347fc0d7d91ab343013209a5e0e66f90d67767250a70310c4a26`, `0xb1c1f9b7a84259b7cb60a7efe8da2e4a30bb5fb96c550cbeb916f605ea38d077` |
| pool initialization (tick 0, zero liquidity) | deployer | `PoolManager.initialize` | `0x657e761691f06258b009f746ce558f1d6be5e923ac03cfe5cffa3c838754a5fc` |
| PES configure and activate | configuration authority | `StandbyHook.configureAndActivate(key, true, -240, 240, registry, exerciseRouter, establishmentAuthority)` | `0x1323860635efe5d9f8cd9790fdb04d38ae9153cfa97ae52e7e031cfb7821205c` |
| beneficiary eligibility | registry admin | `setBeneficiaryEligibility(beneficiary, true)` | `0x706d65ff7fccdc073d3cabf241ccfb78f5cdff3e90056dbeb00c0b52c3d6529f` |
| trader eligibility | registry admin | `setTraderEligibility(trader, true)` | `0x9ecd8e12d6fe1a4089a888628be85ca1e0f7d0253eca2238bf066a9336161cbd` |
| liquidity eligibility | registry admin | `setLiquidityEligibility(liquidityProvider, true)` | `0xcc674d08247ddfc00da00914b23200869382fd52f0a6ae107e49442329c407ab` |
| fixture funding ×5 | deployer | `mint` | `0xca37f8e351d17faf6f9c5006e6701911448ad425f7dc5c2d612a2e9d5256fb6d`, `0x79aeefb7f3bcb955a2c70d2cb7d8d1e78966e57121d45649450ba2c95ed26ad8`, `0x5aaa0c292c4e4b352baa5cac371fa4fcb940b6b7c699426708c0af260da0e8cc`, `0xde66a91748ace86c90a2396ba126159b20082b00b0512c1e434469d557df7df1`, `0xface2ffccf98a516409d6b6b723cbfc0b12710dd23fbf1c6bfa2217786480b38` |
| LP MockUSTB → Permit2 / Permit2 → PositionManager | liquidity provider | `approve` / `Permit2.approve` | `0x0a1de39ec3ad9e3304018c3191c89f6e6f2ba721f3b7a01b98631bd7ec32ab70`, `0xe64ca734883310d584bd2f31ae8d76dfe752b08312e8453e7073e592b920df34` |
| LP MockUSDC → Permit2 / Permit2 → PositionManager | liquidity provider | `approve` / `Permit2.approve` | `0xed5d172876e3864e379ff72d3cd5f5a9f825126e3d3e2be183690fcbae5aa631`, `0x46f837865e2d1cba015bf3578c3cb8a7b735b8c0a014e3b14e4ef63c5742aef2` |
| trader MockUSTB → Permit2 / Permit2 → Universal Router | trader | `approve` / `Permit2.approve` | `0xf77b21336a641331dac30580485a3432ba091e7e13d784ea22a2137f57141ea8`, `0xd5a5e89e75a52bc9162f3add28811bf7d14131e148b08a46353f696a2e4409e4` |
| exerciser MockUSTB → ExerciseRouter (accepted ERC20 path) | exercise authority | `approve` | `0x682481585f54a8d9abeca1025c8840b66a858bddae70169476a471b8e347947b` |
| canonical liquidity through official PositionManager | liquidity provider | `PositionManager.modifyLiquidities` (`MINT_POSITION`, `SETTLE_PAIR`) | `0xaab76a80256d43952e1216a7356d2c24446813f7232d9492db9031ba02975bea` |

### Bootstrap authoritative state (re-read from the mined chain)

| Quantity | Value |
| -------- | ----- |
| Supporting Capacity S | 80,000.000000 MockUSDC (`80000000000`) |
| Aggregate Capacity Obligation O | 0 |
| `nextCommitmentId` | 1 (no commitment) |
| active liquidity (StateView) | 6,707,079,990,254 |
| slot0 tick / lpFee / protocolFee | 0 / 500 / 0 |
| eligibility | LP: liquidity only; trader: swap only; beneficiary: protected service only; exerciser: none |
| Permit2 allowances | LP→PositionManager (MockUSTB, MockUSDC), trader→Universal Router (MockUSTB): `uint160.max`, expiry `uint48.max` |

---

## 5. Public A1–A4 lifecycle

Each stage was broadcast (or, for A3, simulated) separately and then re-verified against the mined chain with
`BaseSepoliaActions.verifyBaseSepoliaState`, which also requires zero MockUSDC at the Hook and ExerciseRouter.

### A1 — PROMISE

| Item | Value |
| ---- | ----- |
| Tx | `0x40d7b3de0fb4e153c7afbe4d8b8fb04b5021091b75a3492f9a6868885a038c50` (status `0x1`, block 46836587) |
| Call | `StandbyHook.establishCommitment(beneficiary, exerciseAuthority, 50000000000, 1789441454, 1792033454)` from the establishment authority |
| Commitment id | 1 |
| Result | **S = 80,000 · O = 50,000 · Remaining = 50,000** |

### A2 — SHARE (official Universal Router)

| Item | Value |
| ---- | ----- |
| Tx | `0x01007a48033697bcaa59e0b841fb81ea2f9f5bb6a81c430d949f7a26e7f3488e` (status `0x1`, block 46836637) |
| Call | `UniversalRouter.execute(V4_SWAP [SWAP_EXACT_OUT_SINGLE, SETTLE_ALL, TAKE_ALL])` from the trader |
| PoolManager `Swap` sender | `0x492e6456d9528771018deb9e87ef7750ef184104` (official Universal Router) |
| Receipt transfers | MockUSTB trader → PoolManager 15,041.142406; MockUSDC PoolManager → trader 15,000.000000 |
| Prospective S′ (Hook derivation) | 65,000 |
| Result | **S = 65,000 · O = 50,000 · Remaining = 50,000** |

The ordinary trade was admitted by the Hook through the official router's authenticated `msgSender()` (the trader
is trader-eligible; the router itself is not an eligible account).

### A3 — PROTECT (official Universal Router, refused)

| Item | Value |
| ---- | ----- |
| Attempt | exact-output 20,000 MockUSDC through the official Universal Router as the trader (simulated against live state; a refused transition has no committed transaction) |
| Current S / prospective S′ / O | 65,000 / **45,000** / 50,000 |
| Refusal | exactly `WrappedError(StandbyHook, beforeSwap 0x575e24b4, StandbyHook__InsufficientProspectiveBacking(45000000000, 50000000000), HookCallFailed 0xa9e35b2f)` |
| State after | **S = 65,000 · O = 50,000 · Remaining = 50,000** (re-verified on chain) |

Independently reproducible evidence: an `eth_call` of the exact router calldata from the trader at pinned block
**46836645** (after A2, before A4) returns revert data byte-identical to the independently encoded expectation:

```text
revert data
0x90bfb86500000000000000000000000092e89da9fe8a103f4864914b268ec364f6458ac0575e24b40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000447ef30e6f0000000000000000000000000000000000000000000000000000000a7a3582000000000000000000000000000000000000000000000000000000000ba43b7400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004a9e35b2f00000000000000000000000000000000000000000000000000000000
```

```bash
cast call 0x492E6456D9528771018DeB9E87ef7750EF184104 --from 0xfCB6999229390D944e074a32f2137d3aBD20e39d \
  --block 46836645 --rpc-url <base-sepolia> --data 0x3593564c000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000006aa8c43a00000000000000000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000340000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000003080c0f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000001e00000000000000000000000000000000000000000000000000000000000000240000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000000200000000000000000000000006334956a63f676efc4f44cc330aa0f0546d4f6c8000000000000000000000000ec64e378231542fdd2eedf2a1763a041c2dda52300000000000000000000000000000000000000000000000000000000000001f4000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000092e89da9fe8a103f4864914b268ec364f6458ac0000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000004a817c800000000000000000000000000000000000000000000000000000000174876e8000000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000006334956a63f676efc4f44cc330aa0f0546d4f6c8000000000000000000000000000000000000000000000000000000174876e8000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000ec64e378231542fdd2eedf2a1763a041c2dda52300000000000000000000000000000000000000000000000000000004a817c800
```

The refusal names both compared quantities, so it cannot be an allowance, balance, eligibility, slippage, liquidity,
service-domain, or gas failure.

### A4 — FULFILL (ExerciseRouter)

| Item | Value |
| ---- | ----- |
| Tx | `0x983b351e22b784f32b2749546c6fa50cde7e8de8e53f95c7c2e44d75da2483ce` (status `0x1`, block 46836674) |
| Call | `ExerciseRouter.exercise(1, 50000000000, 100000000000)` from the exercise authority |
| PoolManager `Swap` sender | `0x17c3ff4a5dd943359699d44bf14058ce4f31c187` (ExerciseRouter) |
| Input settlement | MockUSTB **exercise authority → PoolManager** 50,627.787984 (the exerciser is the payer) |
| Protected delivery | MockUSDC **PoolManager → beneficiary** 50,000.000000 (direct; no ExerciseRouter hop in the receipt) |
| Hook event | `ExerciseFinalized` (topic0 `0x12c2ca552f0b7b62fcbd074aa5f0daaf4d1df728db7f593d364ca5b3511d131e`) |
| Beneficiary MockUSDC | block 46836673: 0 → block 46836674: 50,000.000000 (**+50,000**) |
| Exerciser MockUSTB | 1,000,000.000000 → 949,372.212016; exerciser MockUSDC 0 |
| Custody after | StandbyHook: 0 MockUSDC, 0 MockUSTB · ExerciseRouter: 0 MockUSDC, 0 MockUSTB |
| Exercise authorization state after | EMPTY |
| Result | **S = 15,000 · O = 0 · Remaining = 0** |

---

## 6. Reproduction

Pre-broadcast, the full sequence was rehearsed stage by stage on a local Anvil fork of live Base Sepolia (the real
deployed PoolManager, Universal Router, PositionManager, and Permit2 bytecode) with identical results and identical
deterministic addresses.

```bash
# requires BASE_RPC_URL and a funded PRIVATE_KEY (and BASESCAN_API_KEY for source verification) in .env
./script/testnet/run-base-sepolia.sh preflight
./script/testnet/run-base-sepolia.sh deploy
./script/testnet/run-base-sepolia.sh bootstrap
COMMITMENT_ID=0 ./script/testnet/run-base-sepolia.sh verify 80000000000 0 0
./script/testnet/run-base-sepolia.sh a1
./script/testnet/run-base-sepolia.sh verify 80000000000 50000000000 50000000000
./script/testnet/run-base-sepolia.sh a2
./script/testnet/run-base-sepolia.sh verify 65000000000 50000000000 50000000000
./script/testnet/run-base-sepolia.sh a3
./script/testnet/run-base-sepolia.sh verify 65000000000 50000000000 50000000000
./script/testnet/run-base-sepolia.sh a4
./script/testnet/run-base-sepolia.sh verify 15000000000 0 0
```

A fresh deployer key produces fresh addresses; the addresses above are the result of this deployment. Foundry's
transaction records for this deployment are under `broadcast/*/84532/`.

No secret appears in this document, the session log, the broadcast records, or any tracked file.

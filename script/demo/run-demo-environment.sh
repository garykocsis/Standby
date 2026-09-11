#!/usr/bin/env bash
#
# Standby — deterministic demo environment runner.
#
# Composes the judged demo environment on a running local Anvil node by invoking the canonical Standby
# scripts, and then writes the address/parameter manifest the frontend reads.
#
# It constructs nothing itself. Deployment is `script/DeployDemoEnvironment.s.sol`, the canonical pre-A1
# state is `script/BootstrapStandby.s.sol`, and the canonical proposed-transaction parameters are reported
# by `script/DemoActions.s.sol`. This file supplies the deterministic role accounts, sequences those three
# invocations, and records what they produced.
#
# Reset is environmental: stop Anvil, start a fresh one, run this again.
#
# Usage:
#   anvil                                  # in another terminal
#   ./script/demo/run-demo-environment.sh  # optional: RPC_URL=... to point elsewhere

set -euo pipefail

RPC_URL="${RPC_URL:-http://127.0.0.1:8545}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST_PATH="${REPO_ROOT}/frontend/public/standby-demo.json"
ENV_PATH="${REPO_ROOT}/demo.env"

# The deterministic default Anvil accounts, one per role. Every role is a separate account: collapsing two
# of them would make a later observation ambiguous. None of these accounts is a Standby authority by virtue
# of appearing here — authority is established on-chain by the deployed contracts.
DEPLOYER=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
export STANDBY_CONFIGURATION_AUTHORITY=0x70997970C51812dc3A010C7d01b50e0d17dc79C8
export STANDBY_ESTABLISHMENT_AUTHORITY=0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
export STANDBY_REGISTRY_ADMIN=0x90F79bf6EB2c4f870365E785982E1f101E93b906
export STANDBY_LIQUIDITY_PROVIDER=0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65
export STANDBY_TRADER=0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc
export STANDBY_BENEFICIARY=0x976EA74026E726554dB657fA54763abd0C3a0aa9
export STANDBY_EXERCISE_AUTHORITY=0x14dC79964da2C08b23698B3D3cc7Ca32193d9955

cd "${REPO_ROOT}"

echo "==> Deploying the Standby demo environment to ${RPC_URL}"

DEPLOY_LOG="$(mktemp)"
trap 'rm -f "${DEPLOY_LOG}" "${PARAMS_LOG:-}"' EXIT

forge script script/DeployDemoEnvironment.s.sol \
  --rpc-url "${RPC_URL}" --broadcast --unlocked --sender "${DEPLOYER}" | tee "${DEPLOY_LOG}"

# Reads one address the deployment script reported. The manifest is the deployment's own output; nothing
# here recomputes or guesses an address.
deployed() {
  local address
  address="$(grep -m 1 "Standby $1:" "${DEPLOY_LOG}" | grep -o '0x[0-9a-fA-F]\{40\}' || true)"

  if [[ -z "${address}" ]]; then
    echo "error: deployment did not report an address for '$1'" >&2
    exit 1
  fi

  echo "${address}"
}

export STANDBY_POOL_MANAGER="$(deployed 'PoolManager')"
export STANDBY_USTB="$(deployed 'MockUSTB')"
export STANDBY_USDC="$(deployed 'MockUSDC')"
export STANDBY_REGISTRY="$(deployed 'registry')"
export STANDBY_SWAP_PERIMETER="$(deployed 'swap perimeter')"
export STANDBY_LIQUIDITY_PERIMETER="$(deployed 'LP perimeter')"
export STANDBY_HOOK="$(deployed 'Hook')"
export STANDBY_EXERCISE_ROUTER="$(deployed 'ExerciseRouter')"

echo "==> Bootstrapping to the canonical pre-A1 state"

forge script script/BootstrapStandby.s.sol \
  --rpc-url "${RPC_URL}" --broadcast --unlocked --sender "${DEPLOYER}"

echo "==> Reading the canonical demo parameters"

PARAMS_LOG="$(mktemp)"

forge script script/DemoActions.s.sol --sig 'printDemoParameters()' \
  --rpc-url "${RPC_URL}" | tee "${PARAMS_LOG}" > /dev/null

# Reads one canonical proposed-transaction parameter the demo script reported. These come from the frozen
# fixture library and the pinned Uniswap tick math, so the presentation layer never restates either.
parameter() {
  local value
  value="$(grep -m 1 "STANDBY_PARAM $1 " "${PARAMS_LOG}" | awk '{print $NF}' || true)"

  if [[ -z "${value}" ]]; then
    echo "error: demo parameters did not report '$1'" >&2
    exit 1
  fi

  echo "${value}"
}

mkdir -p "$(dirname "${MANIFEST_PATH}")"

cat > "${MANIFEST_PATH}" <<JSON
{
  "chainId": 31337,
  "rpcUrl": "${RPC_URL}",
  "addresses": {
    "poolManager": "${STANDBY_POOL_MANAGER}",
    "ustb": "${STANDBY_USTB}",
    "usdc": "${STANDBY_USDC}",
    "registry": "${STANDBY_REGISTRY}",
    "swapPerimeter": "${STANDBY_SWAP_PERIMETER}",
    "liquidityPerimeter": "${STANDBY_LIQUIDITY_PERIMETER}",
    "hook": "${STANDBY_HOOK}",
    "exerciseRouter": "${STANDBY_EXERCISE_ROUTER}"
  },
  "actors": {
    "configurationAuthority": "${STANDBY_CONFIGURATION_AUTHORITY}",
    "establishmentAuthority": "${STANDBY_ESTABLISHMENT_AUTHORITY}",
    "registryAdmin": "${STANDBY_REGISTRY_ADMIN}",
    "liquidityProvider": "${STANDBY_LIQUIDITY_PROVIDER}",
    "trader": "${STANDBY_TRADER}",
    "beneficiary": "${STANDBY_BENEFICIARY}",
    "exerciseAuthority": "${STANDBY_EXERCISE_AUTHORITY}"
  },
  "parameters": {
    "sqrtPriceLimitX96": "$(parameter sqrtPriceLimitX96)",
    "commitmentQ": "$(parameter commitmentQ)",
    "compatibleSwapOutput": "$(parameter compatibleSwapOutput)",
    "destructiveSwapOutput": "$(parameter destructiveSwapOutput)",
    "exerciseMaxInput": "$(parameter exerciseMaxInput)",
    "validityDuration": "$(parameter validityDuration)",
    "protectedZeroForOne": $(parameter protectedZeroForOne)
  }
}
JSON

# The same deployed manifest, in the form the Solidity scripts read it. `DemoActions.s.sol` is run from a
# shell that has sourced this file, so the non-browser path acts on exactly the environment just deployed.
cat > "${ENV_PATH}" <<ENV
export RPC_URL=${RPC_URL}
export STANDBY_DEPLOYER=${DEPLOYER}
export STANDBY_POOL_MANAGER=${STANDBY_POOL_MANAGER}
export STANDBY_USTB=${STANDBY_USTB}
export STANDBY_USDC=${STANDBY_USDC}
export STANDBY_REGISTRY=${STANDBY_REGISTRY}
export STANDBY_SWAP_PERIMETER=${STANDBY_SWAP_PERIMETER}
export STANDBY_LIQUIDITY_PERIMETER=${STANDBY_LIQUIDITY_PERIMETER}
export STANDBY_HOOK=${STANDBY_HOOK}
export STANDBY_EXERCISE_ROUTER=${STANDBY_EXERCISE_ROUTER}
export STANDBY_CONFIGURATION_AUTHORITY=${STANDBY_CONFIGURATION_AUTHORITY}
export STANDBY_ESTABLISHMENT_AUTHORITY=${STANDBY_ESTABLISHMENT_AUTHORITY}
export STANDBY_REGISTRY_ADMIN=${STANDBY_REGISTRY_ADMIN}
export STANDBY_LIQUIDITY_PROVIDER=${STANDBY_LIQUIDITY_PROVIDER}
export STANDBY_TRADER=${STANDBY_TRADER}
export STANDBY_BENEFICIARY=${STANDBY_BENEFICIARY}
export STANDBY_EXERCISE_AUTHORITY=${STANDBY_EXERCISE_AUTHORITY}
ENV

echo "==> Wrote ${MANIFEST_PATH} and ${ENV_PATH}"
echo
echo "The environment now stands at the canonical pre-A1 state: S = 80,000 MockUSDC, O = 0, no commitment."
echo "Run the interface with 'cd frontend && npm run dev', or the non-browser path with:"
echo "  source demo.env"
echo "  forge script script/DemoActions.s.sol --rpc-url \$RPC_URL --broadcast --unlocked --sender \$STANDBY_DEPLOYER"

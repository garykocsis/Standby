#!/usr/bin/env bash
#
# Standby — supplementary post-submission F9T runner for Base Sepolia (chain id 84532).
#
# Base Sepolia is NOT the canonical judged environment. Canonical acceptance and the judged demo run on
# deterministic local Anvil (see script/demo/run-demo-environment.sh). This runner reproduces the same accepted
# lifecycle against the official public Uniswap v4 stack as supplementary evidence.
#
# It constructs nothing itself. It sequences the F9T Solidity scripts one stage at a time, so every stage is its
# own broadcast and can be verified against the mined chain before the next one runs:
#
#   preflight   simulate the whole deployment against live state, broadcasting nothing
#   deploy      deploy MockUSTB, MockUSDC, EligibilityRegistry, StandbyHook, ExerciseRouter; write the manifest
#   bootstrap   initialize, activate, seed eligibility, fund/approve, add canonical liquidity (S = 80,000, O = 0)
#   a1          admit the canonical 50,000 MockUSDC commitment
#   a2          compatible 15,000 MockUSDC ordinary swap through the official Universal Router
#   a3          destructive 20,000 MockUSDC ordinary swap attempt through the official Universal Router (simulated;
#               must be refused by the Standby backing requirement)
#   a4          exercise the commitment in full through the ExerciseRouter
#   verify S O R
#               re-read the mined chain and require Supporting Capacity S, Obligation O, Remaining Entitlement R
#
# Inputs, read from the environment or from a git-ignored .env at the repository root:
#   BASE_RPC_URL (or RPC_URL)   Base Sepolia RPC endpoint
#   PRIVATE_KEY                 funded Base Sepolia deployer key; role keys are derived from it in-script
#   BASESCAN_API_KEY            only when VERIFY=1 is set for the deploy stage
#   COMMITMENT_ID               defaults to 1, the first identity the canonical bootstrap leaves unused
#   STANDBY_MANIFEST            defaults to base-sepolia.env at the repository root (git-ignored)
#
# Secrets are never echoed. Do not add -vvvv to these invocations: cheatcode traces would print key material.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

export ETH_RPC_URL="${RPC_URL:-${BASE_RPC_URL:-}}"

if [[ -z "${ETH_RPC_URL}" ]]; then
  echo "error: set BASE_RPC_URL (or RPC_URL) to a Base Sepolia endpoint" >&2
  exit 1
fi

if [[ -z "${PRIVATE_KEY:-}" ]]; then
  echo "error: set PRIVATE_KEY to the funded Base Sepolia deployer key" >&2
  exit 1
fi

MANIFEST="${STANDBY_MANIFEST:-${REPO_ROOT}/base-sepolia.env}"
COMMITMENT_ID="${COMMITMENT_ID:-1}"
STAGE="${1:-}"

RPC=(--rpc-url "${ETH_RPC_URL}")
BROADCAST=(--broadcast --slow --private-key "${PRIVATE_KEY}")

# Removes any URL and every execution-trace line from forge output. A failing script prints its call trace even
# at default verbosity, and that trace includes cheatcode return values — the root key read from the environment
# among them — so trace lines are dropped rather than trusted not to carry key material.
redact() {
  sed -E 's#https?://[^[:space:]"]+#<redacted-url>#g' \
    | grep -vE '^[[:space:]]*(\[[0-9]+\]|├─|└─|│|←)' || true
}

load_manifest() {
  if [[ ! -f "${MANIFEST}" ]]; then
    echo "error: no manifest at ${MANIFEST}; run the deploy stage first" >&2
    exit 1
  fi

  # shellcheck disable=SC1090
  source "${MANIFEST}"
}

actions() {
  forge script script/testnet/BaseSepoliaActions.s.sol "${RPC[@]}" "$@" 2>&1 | redact
}

case "${STAGE}" in
  preflight)
    forge script script/testnet/DeployBaseSepoliaEnvironment.s.sol "${RPC[@]}" 2>&1 | redact
    ;;

  deploy)
    DEPLOY_LOG="$(mktemp)"
    trap 'rm -f "${DEPLOY_LOG}"' EXIT

    VERIFY_FLAGS=()
    if [[ "${VERIFY:-0}" == "1" ]]; then
      VERIFY_FLAGS=(--verify --etherscan-api-key "${BASESCAN_API_KEY:?set BASESCAN_API_KEY for VERIFY=1}")
    fi

    forge script script/testnet/DeployBaseSepoliaEnvironment.s.sol "${RPC[@]}" "${BROADCAST[@]}" ${VERIFY_FLAGS[@]+"${VERIFY_FLAGS[@]}"} 2>&1 \
      | redact | tee "${DEPLOY_LOG}"

    # Reads one address the deployment script reported; nothing here recomputes or guesses an address.
    deployed() {
      local address
      address="$(grep -m 1 "Standby $1:" "${DEPLOY_LOG}" | grep -o '0x[0-9a-fA-F]\{40\}' || true)"

      if [[ -z "${address}" ]]; then
        echo "error: deployment did not report an address for '$1'" >&2
        exit 1
      fi

      echo "${address}"
    }

    cat > "${MANIFEST}" <<ENV
export STANDBY_USTB=$(deployed 'MockUSTB')
export STANDBY_USDC=$(deployed 'MockUSDC')
export STANDBY_REGISTRY=$(deployed 'registry')
export STANDBY_HOOK=$(deployed 'Hook')
export STANDBY_EXERCISE_ROUTER=$(deployed 'ExerciseRouter')
ENV

    echo "==> Wrote ${MANIFEST}"
    ;;

  bootstrap)
    load_manifest
    forge script script/testnet/BootstrapBaseSepolia.s.sol "${RPC[@]}" --sig 'bootstrapBaseSepolia()' "${BROADCAST[@]}" 2>&1 | redact
    ;;

  a1)
    load_manifest
    actions --sig 'admitCommitmentBaseSepolia()' "${BROADCAST[@]}"
    ;;

  a2)
    load_manifest
    actions --sig 'compatibleOrdinarySwapBaseSepolia(uint256)' "${COMMITMENT_ID}" "${BROADCAST[@]}"
    ;;

  a3)
    load_manifest
    actions --sig 'attemptDestructiveOrdinarySwapBaseSepolia(uint256)' "${COMMITMENT_ID}"
    ;;

  a4)
    load_manifest
    actions --sig 'exerciseCommitmentBaseSepolia(uint256)' "${COMMITMENT_ID}" "${BROADCAST[@]}"
    ;;

  verify)
    load_manifest
    actions --sig 'verifyBaseSepoliaState(uint256,uint256,uint256,uint256)' \
      "${COMMITMENT_ID}" "${2:?expected S}" "${3:?expected O}" "${4:?expected Remaining}"
    ;;

  *)
    echo "usage: $0 {preflight|deploy|bootstrap|a1|a2|a3|a4|verify S O R}" >&2
    exit 2
    ;;
esac

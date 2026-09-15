# Session 21 Follow-up — Add Reproduction Environment Example

## Objective

Make one small documentation/reproducibility improvement to the completed F9T Base Sepolia work:

Add a tracked `.env.example` that documents the user-supplied environment variables required to reproduce the Base Sepolia deployment, and ensure `docs/setup.md` points users to it.

This is a bounded Session 21 follow-up.

Do **not** reopen F9T implementation, protocol design, deployment architecture, or G9T derivation.

---

## Clean Rule

Preserve the established ownership rule:

**CLAUDE.md owns permanent operating behavior.**

**.claude/rules/\* owns permanent Solidity/testing conventions.**

**Session prompts own only slice-specific objective, scope, requirements, prohibitions, file boundaries, gate evidence, and completion boundary.**

Do not modify `CLAUDE.md` or `.claude/rules/*`.

---

## Current State

F9T Base Sepolia implementation and live execution are complete.

The public deployment reproduced the canonical Standby A1–A4 lifecycle through the official Uniswap v4 Base Sepolia stack.

Independent ChatGPT review has found no implementation correction required.

The repository currently uses:

- `.env` for user-supplied local secrets/configuration;
- `base-sepolia.env` as a generated, git-ignored deployment manifest;
- `docs/reports/f9t-base-sepolia-deployment.md` as the tracked public deployment evidence.

These responsibilities must remain distinct.

---

## Required Change

### 1. Add `.env.example`

Create a tracked repository-root file:

```text
.env.example
```

It should document only the user-supplied inputs required by the F9T reproduction path.

Use the environment-variable names actually consumed by the existing implementation.

Expected content is conceptually:

```bash
# Base Sepolia RPC endpoint
BASE_RPC_URL=

# Dedicated Base Sepolia deployment/test private key
PRIVATE_KEY=

# Optional: contract source verification
BASESCAN_API_KEY=
```

Before writing the file, inspect the actual Session 21 scripts and `docs/setup.md` and confirm the exact environment-variable names.

The repository implementation is authoritative if any spelling differs from the conceptual example above.

Do not put any real RPC URL, API key, private key, wallet key, mnemonic, or other secret into `.env.example`.

Do not put deployed Standby addresses into `.env.example`.

---

### 2. Do NOT create `.base-sepolia.env.sample`

Do not create:

```text
.base-sepolia.env.sample
```

or:

```text
base-sepolia.env.example
```

`base-sepolia.env` is generated deployment state/output, not user-supplied configuration.

It must remain generated and git-ignored.

The distinction is:

```text
.env.example
    tracked
    documents required user inputs

.env
    ignored
    contains actual local secrets/configuration

base-sepolia.env
    ignored
    generated deployment manifest/state

docs/reports/f9t-base-sepolia-deployment.md
    tracked
    public F9T deployment evidence
```

Preserve this separation.

---

## docs/setup.md

Inspect the existing F9T Base Sepolia reproduction instructions in `docs/setup.md`.

Make the **minimum documentation edit necessary** so a new reproducer knows to:

1. copy or use `.env.example` as the template for their local `.env`;
2. populate the required Base Sepolia RPC URL;
3. use a dedicated funded Base Sepolia test/deployment private key;
4. optionally provide the explorer API key when source verification is desired;
5. never commit `.env`;
6. allow the F9T scripts to generate `base-sepolia.env` rather than manually creating it.

Do not duplicate the full deployment procedure if it is already documented.

Do not alter the canonical Anvil setup or judged acceptance instructions.

---

## Security Requirements

Verify that:

- `.env` remains git-ignored;
- `base-sepolia.env` remains git-ignored;
- `.env.example` is **not** ignored;
- `.env.example` contains no real credentials;
- no existing credential or RPC secret is introduced into tracked files;
- no deployment private key is printed or persisted as part of this change.

The previously exposed RPC provider key has already been rotated. Do not record the old or replacement key anywhere.

---

## Allowed Files

Expected modifications are limited to:

```text
.env.example
docs/setup.md
docs/prompts/session-21-log.md
```

Only modify `.gitignore` if inspection proves `.env.example` would otherwise be ignored and a narrowly scoped exception is necessary.

Do not modify:

```text
src/*
script/testnet/*
script/helpers/*
test/*
lib/*
foundry.toml
remappings.txt
README.md
docs/project-status.md
CLAUDE.md
.claude/rules/*
docs/reports/f9t-base-sepolia-deployment.md
```

unless you discover a genuine contradiction that prevents this bounded task. If so, stop and report it rather than expanding scope.

---

## Session Log

Update:

```text
docs/prompts/session-21-log.md
```

Record this follow-up instruction under the existing material-follow-up-prompt section.

Record:

- why `.env.example` was added;
- that `base-sepolia.env` remains generated and ignored;
- files changed;
- security checks performed;
- verification results.

Do not rewrite the previous implementation chronology.

---

## Verification

At minimum verify:

```bash
git check-ignore .env
git check-ignore base-sepolia.env
git check-ignore .env.example
```

Expected result:

```text
.env                  ignored
base-sepolia.env      ignored
.env.example          NOT ignored
```

Inspect `.env.example` and the resulting diff for secrets.

Also run the appropriate lightweight repository checks needed to establish that this documentation-only/reproduction change has not disturbed the completed F9T implementation.

Do not rerun the live Base Sepolia lifecycle.

Do not redeploy contracts.

Do not send any transactions.

---

## Gate Impact

This follow-up strengthens the reproducibility/security evidence associated with G9T-40 and G9T-41.

It does not change any previously derived G9T requirement.

It does not independently close G9T.

Final G9T closure remains owned by independent ChatGPT review after the Session 21 retrospective is complete.

---

## Prohibitions

Do not:

- change Standby protocol semantics;
- modify production contracts;
- modify canonical acceptance;
- modify the Base Sepolia deployment architecture;
- modify public periphery adapters;
- change dependency revisions;
- change Hook permissions;
- change A1–A4 behavior;
- redeploy anything;
- broadcast transactions;
- introduce another environment-template file;
- commit secrets;
- put deployment outputs into `.env.example`;
- modify `docs/project-status.md`;
- begin another implementation slice.

---

## Completion Boundary

The completion boundary for this follow-up is:

```text
.env.example created

actual implementation environment-variable names confirmed

.env.example contains only placeholders and explanatory comments

.env remains ignored

base-sepolia.env remains ignored

.env.example confirmed tracked / not ignored

docs/setup.md minimally updated to reference .env.example

generated base-sepolia.env responsibility remains unchanged

no real credentials introduced

no Base Sepolia transaction broadcast

no Standby implementation changed

docs/prompts/session-21-log.md updated with this follow-up

lightweight repository verification complete

completion report produced
```

Stop at this completion boundary.

Do not begin another F9T change or another Standby slice.

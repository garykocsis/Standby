# Protocol Discovery Methodology

This directory contains the formal methodology artifacts produced from the Standby protocol project and its post-project methodology retrospective.

## Current Methodology

**Protocol Discovery Methodology v1.1** is the current frozen methodology.

See:

- [`protocol-discovery-methodology-v1.1.md`](./protocol-discovery-methodology-v1.1.md)

Protocol Discovery Methodology v1.1 preserves the economic derivation model used to develop Standby while incorporating refinements validated through the formal Standby retrospective.

## Provenance

Standby was developed using **Protocol Discovery Methodology v1.0** as its methodology baseline.

The original frozen v1.0 methodology artifact is not reproduced in this repository. The historical Standby artifacts therefore remain the evidence of the methodology and project decisions in force while Standby was designed and implemented.

The methodology evolution represented here is:

```text
Protocol Discovery Methodology v1.0
        │
        │ applied during Standby discovery and implementation
        ▼
Standby
        │
        │ contemporaneous design, implementation,
        │ verification, and review evidence
        ▼
Standby Methodology Retrospective
        │
        │ R0–R7 evidence-based evaluation
        ▼
Protocol Discovery Methodology v1.1
```

## Standby Retrospective

The formal retrospective is:

- [`retrospectives/standby-methodology-retrospective.md`](./retrospectives/standby-methodology-retrospective.md)

The retrospective is **evidentiary and non-normative**.

It records the R0–R7 evaluation of Protocol Discovery Methodology v1.0 against the Standby implementation experience, including supporting evidence, counterevidence, limitations, candidate improvements, validation decisions, and the basis for the v1.1 successor determination.

It explains **why** the methodology changed.

It does not replace or retroactively redefine the historical Standby protocol artifacts.

## Evidence Trail

The formal retrospective is supported by the repository's contemporaneous project evidence, including:

- frozen Standby protocol artifacts under `docs/`;
- implementation and realization artifacts;
- slice-specific implementation prompts and Claude session logs under `docs/prompts/`;
- ChatGPT reasoning records under `docs/prompts/retrospective/`;
- production contracts and tests;
- verification-gate evidence;
- stateful invariant campaigns;
- canonical acceptance evidence;
- demo and submission evidence;
- Base Sepolia public-realization evidence.

These historical artifacts should be interpreted according to the methodology and project decisions in force when they were created.

They are not retroactively rewritten to conform to Protocol Discovery Methodology v1.1.

## Authority Boundary

| Artifact | Role | Authority |
| --- | --- | --- |
| `protocol-discovery-methodology-v1.1.md` | Current methodology | **Normative** |
| `retrospectives/standby-methodology-retrospective.md` | Empirical evaluation and methodology-change rationale | **Non-normative / evidentiary** |
| Historical Standby artifacts | Project design, implementation, verification, and contemporaneous evidence | **Historical authority according to their original ownership and status** |

The retrospective may explain the evidence supporting a methodology change, but it does not independently create normative methodology.

Protocol Discovery Methodology v1.1 is the authoritative statement of the methodology resulting from that evaluation.

## Version Status

| Version | Status |
| --- | --- |
| Protocol Discovery Methodology v1.0 | Historical baseline used for Standby |
| Protocol Discovery Methodology v1.1 | **FROZEN — current version** |
| Protocol Discovery Methodology v2.0 | Not justified by current evidence |
| Protocol Implementation Method | Emergent / provisional |

Future methodology changes should preserve the same distinction between:

**historical evidence → retrospective evaluation → normative methodology revision**

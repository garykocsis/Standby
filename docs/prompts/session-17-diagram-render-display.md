Before making any README or repository changes, perform a **visual-verification step only** for the two frozen Mermaid diagrams below.

Do **not** modify any file.

Do **not** update:

- `README.md`;
- `frontend/README.md`;
- `docs/prompts/session-17-log.md`;
- `docs/project-status.md`;
- or any other repository file.

The purpose of this step is solely to verify the rendered appearance of the two already-frozen diagrams before they are inserted into the judge-facing README.

## Diagram 1 — Standby Execution Paths

Render/display this Mermaid source **exactly as supplied**:

```mermaid id="70yzau"
sequenceDiagram
    participant T as Ordinary Trader
    participant P as Trusted Swap Periphery
    participant PM as Uniswap v4 PoolManager
    participant H as StandbyHook
    participant R as ExerciseRouter
    participant A as Exercise Authority
    participant B as Beneficiary

    Note over H,R: Commitment already exists<br/>with outstanding obligation O

    Note over PM,H: Shared AMM liquidity supports capacity S<br/>StandbyHook protects outstanding obligation O

    T->>P: Submit ordinary swap
    P->>PM: Execute swap
    PM->>H: beforeSwap
    H->>H: Derive prospective supporting capacity S′

    alt S′ ≥ O
        H-->>PM: Permit ordinary transition
        PM-->>P: Complete swap
        P-->>T: Swap succeeds
    else S′ < O
        H-->>PM: Reject transition
        PM-->>P: Revert
        P-->>T: Swap rejected
    end

    A->>R: Exercise existing commitment
    R->>H: Request exercise authorization
    H->>H: Authenticate authority and establish AUTHORIZED context
    H-->>R: Authorized protected execution

    R->>PM: Unlock and execute exact-output swap
    PM->>H: beforeSwap
    H->>H: Match authorized O2 execution<br/>AUTHORIZED → EXECUTING
    H-->>PM: Permit protected execution

    PM->>H: afterSwap with authoritative BalanceDelta
    H->>H: Prove exact protected output q<br/>EXECUTING → EXECUTED
    H-->>PM: Execution accepted

    R->>PM: Settle actual input debt
    PM-->>B: Deliver exactly q protected output

    R->>H: Finalize exercised commitment
    H->>H: Verify final backing<br/>Reduce Remaining by q<br/>Consume causal context
    H-->>R: Fulfillment finalized

    PM-->>R: Unlock completes
    R-->>A: Exercise succeeds
```

## Diagram 2 — Canonical Demo Sequence

Render/display this Mermaid source **exactly as supplied**:

```mermaid id="7f4spx"
flowchart TD
    B["Bootstrap<br/>S = 80k<br/>O = 0"] --> A1

    A1["A1 — Admit 50k commitment<br/>S = 80k<br/>O = 50k<br/>Remaining = 50k"] --> A2

    A2["A2 — Compatible ordinary swap: 15k<br/>S = 65k<br/>O = 50k<br/>Remaining = 50k<br/>Allowed"] --> A3

    A3["A3 — Attempt another 20k ordinary swap<br/>Prospective S′ = 45k<br/>O = 50k<br/>45k < 50k"] --> R["Rejected by Standby backing requirement<br/>Authoritative state remains<br/>S = 65k / O = 50k / Remaining = 50k"]

    R --> A4

    A4["A4 — Exercise full 50k commitment<br/>Beneficiary receives 50k MockUSDC<br/>Remaining = 0<br/>O = 0<br/>Final S = 15k"]
```

## Fidelity Rules

Do not:

- redesign either diagram;
- change participant order;
- change node order;
- rename participants;
- rename nodes;
- change arrows;
- change labels;
- change quantities;
- add styling;
- add colors;
- add classes;
- add icons;
- add subgraphs;
- add Mermaid initialization directives;
- simplify either diagram;
- generate an alternative representation.

If the supplied Mermaid cannot render exactly as written, report the rendering problem rather than correcting it.

## Required Response

Display/render **Diagram 1 and Diagram 2** so they can be visually inspected.

Then report only whether:

1. each diagram rendered successfully;
2. the rendered source is exactly the supplied source;
3. any Mermaid rendering or layout problem was encountered.

**Stop after displaying the diagrams.**

Do not modify the repository.

Do not proceed to the README update.

Wait for explicit approval before taking any further action.

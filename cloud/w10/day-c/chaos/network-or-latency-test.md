# Chaos test - Network or latency

## Goal

Document a controlled network/latency experiment without introducing a heavy chaos framework by default.

## Recommended approach

Start with a simple app-level failure or canary failure before adding Litmus or Chaos Mesh. If a chaos framework is used, keep the blast radius inside `app-dev`.

## Guardrails

- Do not target `kube-system`, `argocd`, `monitoring`, `gatekeeper-system`, `external-secrets`, or `kyverno`.
- Define rollback before running the experiment.
- Record start time, end time, affected workload, and observed recovery.

## Evidence

Record:

- Failure injected.
- Detection signal.
- Recovery action.
- Recovery time.
- Follow-up action.


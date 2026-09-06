# Data route

## Linked TODOs, graph, journal and CLI

The shipped contracts are `Sources/CiderDomain/LinkedWork` and `docs/plans/linked-work/contract-spec.md`. Use the same ready repository for app services, journal-before-acknowledgement, and read-only CLI context. Never infer a link from cwd, treat Stop as Done, or include note bodies without explicit selection. See `docs/progress/linked-work-14.md` for migration/rollback, bounded-history and checkpoint retry details. Automatic hook/skill installation and agent-write commands remain out of scope.


- Read [data contracts](../../../../docs/contracts/data.md) before changing identifiers, event reduction, or persistence.
- Read [document contracts](../../../../docs/contracts/documents.md) for file writes, assets, frontmatter, or conflicts.
- Read [integration research](../../../../docs/research/integrations.md) for provider capability and auth boundaries.
- Consult [reference repositories](../../../../docs/research/reference-codebases.md) only for the provider or display path in scope.
- Use [verification](../../../../docs/verification.md) to separate offline fixture checks from live tests.

Keep a single writer for each durable state domain. Adapters publish versioned observations; they do not mutate SwiftUI models. Unknown/stale status retains provenance. Authentication material belongs in authorized connector setup, not fixtures or logs.


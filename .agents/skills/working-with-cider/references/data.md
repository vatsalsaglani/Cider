# Data route

- Read [data contracts](../../../../docs/contracts/data.md) before changing identifiers, event reduction, or persistence.
- Read [document contracts](../../../../docs/contracts/documents.md) for file writes, assets, frontmatter, or conflicts.
- Read [integration research](../../../../docs/research/integrations.md) for provider capability and auth boundaries.
- Consult [reference repositories](../../../../docs/research/reference-codebases.md) only for the provider or display path in scope.
- Use [verification](../../../../docs/verification.md) to separate offline fixture checks from live tests.

Keep a single writer for each durable state domain. Adapters publish versioned observations; they do not mutate SwiftUI models. Unknown/stale status retains provenance. Authentication material belongs in authorized connector setup, not fixtures or logs.


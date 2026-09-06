# Agent response refinement

The user confirmed real Codex events reached Cider and requested response previews and automatic peeking (2026-09-06).

- Top notch separates tracked parent-session count from TODO count with distinct symbols/tooltips. Session count includes finished responding sessions until ended or expired; it is not a working count.
- Fresh main-session Stop events arriving after initial load trigger a five-second compact peek. Initial replay does not notify. Full HUD stays closed, tab selection and focus remain unchanged. Clicking the header opens the regular HUD and clears the peek. An already expanded HUD is not resized. The outline uses an ember/pink gradient.
- Completion payloads may now retain up to 600 characters of `last_assistant_message`, as requested. Prompts/tool inputs/transcript files remain excluded. Old events have no excerpt; new responses are required. Excerpts are plain text in the workspace/HUD and follow existing local activity retention. This supersedes the original metadata-only response exclusion.
- Installed helper matched the previous bundled executable byte-for-byte before replacement. Its stable command and hook settings were unchanged.
- Codex uses the monochrome OpenAI knot rather than the purple terminal variant. SVG derived from Lobe Icons `src/OpenAI/components/Mono.tsx`, commit `a94750e3f5f8fc33757b839d85030e742284e43a`; MIT license bundled alongside assets. Source: https://github.com/lobehub/lobe-icons . Static assets work in SwiftUI via the existing BrandImage component; no React runtime is included.

Validation: 22 Swift tests passed, including bounded completion-only excerpts and peek/expand/pin separation. Native packaging/launch passed; CUA detected the running workspace. Live response timing, automatic timeout on physical hardware, and final visual appearance require a fresh agent response; not claimed as tested.

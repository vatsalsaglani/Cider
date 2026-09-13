# Cider

Less switching. More flow. Cider keeps your agents, tasks, notes, music, and usage within reach—right from your Mac's notch.

[Get Cider](https://github.com/vatsalsaglani/Cider/releases/latest) · [Website](https://vatsalsaglani.github.io/Cider/) · [User guide](https://vatsalsaglani.github.io/Cider/#/docs/getting-started)

## A calmer corner of your Mac

- See agent activity and know when something needs you.
- Capture today's tasks, link a plan, and define a clear finish line.
- Write in local Markdown notes and keep your folders and tabs close.
- Follow connections between notes, tasks, and conversations.
- Check supported account limits and control Now Playing from the notch.

Cider is an early release for Apple Silicon Macs running macOS 26 or later. The downloadable app is ad hoc signed and is not Apple-notarized. See the [installation guide](site/docs/getting-started.md).

## Build and contribute

Use Xcode with Swift 6.3 or later. Run `swift test` for the unit tests, `./script/build_and_run.sh --package` to build `dist/Cider.app`, or `./script/build_and_run.sh run` to build and launch. See the script's supported options before changing the packaging flow.

The React/Tailwind website and Markdown user guides live in [`site/`](site/README.md). Native development context starts in [AGENTS.md](AGENTS.md), with current evidence in [docs/progress/current.md](docs/progress/current.md).

## Releases

Push a branch named `release/0.0.1` or `release/v0.0.1`. GitHub Actions tests and packages that branch, then publishes tag `v0.0.1` with a ZIP, SHA-256 checksum, and the matching version section from [CHANGELOG.md](CHANGELOG.md). Later pushes to the same release branch update the tag, replace the assets, and refresh the release notes after the build succeeds. Published release versions are therefore mutable while their branches are being updated.

Main pushes run native CI. Changes under `site/` deploy the website through GitHub Pages Actions.

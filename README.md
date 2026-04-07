# Homebrew Tap: aeongames/ports

This tap stores Homebrew formulas for dependencies used by Aeon Games projects
that are not available (or not suitable) in official Homebrew taps.

## Purpose

- Provide reproducible formulas for project dependencies.
- Pin upstream source revisions when needed for build stability.
- Keep Aeon project-specific packaging logic separate from app repositories.

## Formulas

Current formulas in this tap:

- `skia-aeongui`
	- Skia static build for macOS, configured for AeonGUI usage.
	- Includes Metal and Vulkan backend support.
	- Source is pinned to a stable Skia branch revision.

## Usage

Tap the repository:

```bash
brew tap aeongames/ports
```

Install formula:

```bash
brew install --build-from-source aeongames/ports/skia-aeongui
```

Install HEAD variant (tip-of-tree):

```bash
brew reinstall --HEAD --build-from-source aeongames/ports/skia-aeongui
```

## Local Development

From this repository, you can test with a local file tap:

```bash
./scripts/test-local-tap.sh
```

## Updating a Formula

For Skia stable pin updates:

```bash
python3 scripts/update-skia-formula.py
```

Optional CI/check mode:

```bash
python3 scripts/update-skia-formula.py --check
```

## Release Checklist

Before pushing updates to this tap:

- Ensure formula file is in `Formula/` and named correctly.
- Validate formula Ruby syntax:

```bash
ruby -c Formula/skia-aeongui.rb
```

- Validate tap install flow from repo root:

```bash
./scripts/test-local-tap.sh
```

- Commit and push:

```bash
git add Formula/skia-aeongui.rb README.md
git commit -m "Update skia-aeongui formula"
git push
```

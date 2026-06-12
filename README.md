# Axiom CLI — releases

Prebuilt binaries for the [Axiom](https://axiomide.com) CLI. This repo contains
**releases and the install script only** — the platform source lives in a
private monorepo.

## Install

**Install script (macOS / Linux):**

```bash
curl -fsSL https://raw.githubusercontent.com/AxiomIDE/axiom-releases/main/install.sh | sh
```

**Homebrew (macOS):**

```bash
brew install axiomide/tap/axiom
```

**Windows:** download the `windows_amd64` `.zip` from
[Releases](https://github.com/AxiomIDE/axiom-releases/releases), unzip, and put
`axiom.exe` on your `PATH`.

Verify:

```bash
axiom version
```

## Docs

Getting started, guides, and the CLI reference: https://axiomide.com

#!/bin/sh
# install.sh — download and install the Axiom CLI.
#
# ADR-067 (2026-06-07) + ADR-084 (2026-06-12): the CLI is distributed as
# prebuilt binaries on GitHub Releases of the PUBLIC binaries-only repo
# AxiomIDE/axiom-releases (built from the private monorepo by
# .goreleaser.yaml). This script is the `curl … | sh` front door:
#
#     curl -fsSL https://raw.githubusercontent.com/AxiomIDE/axiom-releases/main/install.sh | sh
#
# (axiomide.com/install.sh will front this same script once the Cloudflare
# rule is in place.) It is POSIX sh (no bashisms) and shellcheck-clean.
#
# The copy in axiom-releases is published from this file — scripts/install.sh
# in the monorepo is the source of truth; re-sync on change.
#
# Environment overrides:
#   AXIOM_VERSION       release tag to install (default: latest)
#   AXIOM_INSTALL_DIR   install directory     (default: first writable of
#                       /usr/local/bin, $HOME/.local/bin)
#   GITHUB_TOKEN        optional; raises the GitHub API rate limit (the repo
#                       itself is public — no token is required)
set -eu

REPO="AxiomIDE/axiom-releases"
BIN="axiom"

info() { printf '%s\n' "$*"; }
err() {
	printf 'install.sh: %s\n' "$*" >&2
	exit 1
}

# need verifies a required command is on PATH.
need() {
	command -v "$1" >/dev/null 2>&1 || err "required command not found: $1"
}

# detect_os maps `uname -s` to the goos value goreleaser names artifacts with.
detect_os() {
	os="$(uname -s)"
	case "$os" in
	Linux) printf 'linux' ;;
	Darwin) printf 'darwin' ;;
	*) err "unsupported OS: $os (Windows users: install under WSL2, or use the .zip from Releases)" ;;
	esac
}

# detect_arch maps `uname -m` to the goarch value goreleaser names artifacts with.
detect_arch() {
	arch="$(uname -m)"
	case "$arch" in
	x86_64 | amd64) printf 'amd64' ;;
	aarch64 | arm64) printf 'arm64' ;;
	*) err "unsupported architecture: $arch" ;;
	esac
}

# auth_header echoes a curl -H argument when GITHUB_TOKEN is set, else nothing.
# Token is intentionally not interpolated into the format string (shellcheck).
auth_args() {
	if [ -n "${GITHUB_TOKEN:-}" ]; then
		printf '%s' "Authorization: Bearer ${GITHUB_TOKEN}"
	fi
}

# resolve_version turns "latest" into a concrete tag via the GitHub API; any
# other value is treated as an explicit tag and returned unchanged.
resolve_version() {
	want="$1"
	if [ "$want" != "latest" ]; then
		printf '%s' "$want"
		return
	fi
	api="https://api.github.com/repos/${REPO}/releases/latest"
	hdr="$(auth_args)"
	if [ -n "$hdr" ]; then
		body="$(curl -fsSL -H "$hdr" "$api")" || err "could not query latest release (is ${REPO} reachable / GITHUB_TOKEN valid?)"
	else
		body="$(curl -fsSL "$api")" || err "could not query latest release from ${REPO} (network or GitHub API rate limit; set GITHUB_TOKEN to raise the limit)"
	fi
	tag="$(printf '%s' "$body" | grep '"tag_name"' | head -n1 | sed -e 's/.*"tag_name": *"//' -e 's/".*//')"
	[ -n "$tag" ] || err "could not parse latest release tag"
	printf '%s' "$tag"
}

# pick_install_dir returns AXIOM_INSTALL_DIR if set, else the first writable of
# the conventional locations.
pick_install_dir() {
	if [ -n "${AXIOM_INSTALL_DIR:-}" ]; then
		printf '%s' "$AXIOM_INSTALL_DIR"
		return
	fi
	for d in /usr/local/bin "$HOME/.local/bin"; do
		if [ -d "$d" ] && [ -w "$d" ]; then
			printf '%s' "$d"
			return
		fi
	done
	# Default target; the caller falls back to sudo if it is not writable.
	printf '/usr/local/bin'
}

main() {
	need curl
	need tar
	need uname

	os="$(detect_os)"
	arch="$(detect_arch)"
	tag="$(resolve_version "${AXIOM_VERSION:-latest}")"
	# goreleaser strips a leading "v" from the tag for {{.Version}} in archive
	# names (tag v1.2.3 -> axiom_1.2.3_linux_amd64.tar.gz).
	ver="${tag#v}"
	asset="${BIN}_${ver}_${os}_${arch}.tar.gz"
	url="https://github.com/${REPO}/releases/download/${tag}/${asset}"

	info "Installing ${BIN} ${tag} (${os}/${arch})"

	tmp="$(mktemp -d)"
	trap 'rm -rf "$tmp"' EXIT

	hdr="$(auth_args)"
	if [ -n "$hdr" ]; then
		curl -fsSL -H "$hdr" -o "${tmp}/${asset}" "$url" ||
			err "download failed: $url"
	else
		curl -fsSL -o "${tmp}/${asset}" "$url" ||
			err "download failed: $url"
	fi

	tar -xzf "${tmp}/${asset}" -C "$tmp" ||
		err "extract failed: ${asset}"
	[ -f "${tmp}/${BIN}" ] || err "archive did not contain ${BIN}"
	chmod +x "${tmp}/${BIN}"

	dir="$(pick_install_dir)"
	if [ -w "$dir" ] || { [ ! -e "$dir" ] && mkdir -p "$dir" 2>/dev/null; }; then
		mv "${tmp}/${BIN}" "${dir}/${BIN}"
	else
		info "Elevating with sudo to install into ${dir}"
		sudo mkdir -p "$dir"
		sudo mv "${tmp}/${BIN}" "${dir}/${BIN}"
	fi

	info "Installed ${BIN} to ${dir}/${BIN}"
	case ":${PATH}:" in
	*":${dir}:"*) : ;;
	*) info "Note: ${dir} is not on your PATH — add it to use \`${BIN}\` directly." ;;
	esac
	info "Run '${BIN} version' to verify."
}

main "$@"

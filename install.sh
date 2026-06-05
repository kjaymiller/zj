#!/usr/bin/env bash
# install.sh — native installer for zj on macOS and Linux.
#
# Symlinks ./zj into a bin directory and installs the tools it needs by
# downloading the prebuilt binaries straight from each project's GitHub
# releases — no package manager (and no mise) required.
#
#   ./install.sh               install missing dependencies + symlink zj
#   ./install.sh --with-fnox    also install fnox (optional; 1Password tokens)
#   ./install.sh --symlink-only just symlink zj (leave dependencies alone)
#   ./install.sh --uninstall    remove the zj symlink
#   ./install.sh --help         show this help
#
# fnox is optional and NOT installed unless you pass --with-fnox; zj works
# without it (you're prompted for tokens, and gh uses its own auth).
#
# Override the install/bin directory with ZJ_BIN_DIR (default: ~/.local/bin).
# Set GITHUB_TOKEN (or GH_TOKEN) to raise the GitHub API rate limit.

set -uo pipefail

BIN_DIR="${ZJ_BIN_DIR:-$HOME/.local/bin}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zj"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$SCRIPT_DIR/zj"
WITH_FNOX=false

# Required at runtime; fnox is optional (token resolution only) and opt-in.
REQUIRED=(zellij zoxide fzf gh)

# --- pretty output -------------------------------------------------------------

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; GREEN=$'\033[32m'; RED=$'\033[31m'
  YELLOW=$'\033[33m'; CYAN=$'\033[36m'; RESET=$'\033[0m'
else
  BOLD=''; DIM=''; GREEN=''; RED=''; YELLOW=''; CYAN=''; RESET=''
fi

say()   { printf '%s\n' "$*"; }
arrow() { printf '%s→%s %s\n' "$CYAN" "$RESET" "$*"; }
ok()    { printf '  %s✓%s %s\n' "$GREEN" "$RESET" "$*"; }
miss()  { printf '  %s✗%s %s\n' "$RED" "$RESET" "$*"; }
die()   { printf '%serror:%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

usage() {
  say "install.sh — native installer for zj on macOS and Linux."
  say ""
  say "  ./install.sh                install missing dependencies + symlink zj"
  say "  ./install.sh --with-fnox    also install fnox (optional; 1Password tokens)"
  say "  ./install.sh --symlink-only just symlink zj (leave dependencies alone)"
  say "  ./install.sh --uninstall    remove the zj symlink"
  say "  ./install.sh --help         show this help"
  say ""
  say "Env: ZJ_BIN_DIR (default ~/.local/bin), GITHUB_TOKEN (raise API rate limit)."
  exit "${1:-0}"
}

# --- platform / tool metadata --------------------------------------------------

repo_for() {
  case "$1" in
    zellij) echo "zellij-org/zellij" ;;
    zoxide) echo "ajeetdsouza/zoxide" ;;
    fzf)    echo "junegunn/fzf" ;;
    gh)     echo "cli/cli" ;;
    fnox)   echo "jdx/fnox" ;;
  esac
}

# Detect OS/arch and derive the naming tokens each project uses for its assets.
detect_platform() {
  local os machine
  os="$(uname -s)"; machine="$(uname -m)"

  case "$machine" in
    arm64|aarch64) RUST_CPU=aarch64; GO_ARCH=arm64 ;;
    x86_64|amd64)  RUST_CPU=x86_64;  GO_ARCH=amd64 ;;
    *) die "unsupported architecture: $machine" ;;
  esac

  case "$os" in
    Darwin) RUST_OS=apple-darwin;       GH_OS=macOS; FZF_OS=darwin; PLATFORM=macOS ;;
    Linux)  RUST_OS=unknown-linux-musl; GH_OS=linux; FZF_OS=linux;  PLATFORM=Linux ;;
    *) die "unsupported OS: $os" ;;
  esac
}

# An extended-regex matching the correct release asset filename for a tool.
asset_match() {
  case "$1" in
    zellij) echo "zellij-${RUST_CPU}-${RUST_OS}\.tar\.gz$" ;;
    zoxide) echo "zoxide-.*-${RUST_CPU}-${RUST_OS}\.tar\.gz$" ;;
    fnox)   echo "fnox-${RUST_CPU}-${RUST_OS}\.tar\.gz$" ;;
    fzf)    echo "fzf-.*-${FZF_OS}_${GO_ARCH}\.tar\.gz$" ;;
    gh)     echo "_${GH_OS}_${GO_ARCH}\.(tar\.gz|zip)$" ;;
  esac
}

# --- GitHub download -----------------------------------------------------------

gh_api() {
  local token="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
  if [ -n "$token" ]; then
    curl -fsSL -H "Authorization: Bearer $token" "$1"
  else
    curl -fsSL "$1"
  fi
}

# Resolve the download URL for a tool's matching asset in the latest release.
asset_url() {
  local repo="$1" pattern="$2"
  gh_api "https://api.github.com/repos/$repo/releases/latest" \
    | grep -oE '"browser_download_url": *"[^"]*"' \
    | sed -E 's/.*"(https[^"]*)".*/\1/' \
    | grep -E -- "$pattern" \
    | head -1
}

# Download + extract + install a single tool's binary into BIN_DIR.
install_tool() {
  local tool="$1" repo url tmp file bin
  repo="$(repo_for "$tool")"

  url="$(asset_url "$repo" "$(asset_match "$tool")")"
  [ -z "$url" ] && { miss "$tool — no $PLATFORM/$RUST_CPU asset found in $repo"; return 1; }

  tmp="$(mktemp -d)"
  file="$tmp/${url##*/}"
  if ! curl -fsSL "$url" -o "$file"; then
    miss "$tool — download failed"; rm -rf "$tmp"; return 1
  fi

  case "$file" in
    *.zip)
      command -v unzip >/dev/null 2>&1 || { miss "$tool — 'unzip' needed to extract"; rm -rf "$tmp"; return 1; }
      unzip -q "$file" -d "$tmp" ;;
    *)
      tar -xzf "$file" -C "$tmp" ;;
  esac

  # Binary may sit at the top level (zellij, zoxide, fzf, fnox) or under bin/
  # (gh) — find it by name wherever it landed.
  bin="$(find "$tmp" -type f -name "$tool" 2>/dev/null | head -1)"
  [ -z "$bin" ] && { miss "$tool — '$tool' binary not found in archive"; rm -rf "$tmp"; return 1; }

  cp "$bin" "$BIN_DIR/$tool" && chmod +x "$BIN_DIR/$tool"
  rm -rf "$tmp"
  ok "$tool ${DIM}installed → $BIN_DIR/$tool${RESET}"
}

# --- actions -------------------------------------------------------------------

link_zj() {
  [ -f "$SRC" ] || die "$SRC not found."
  mkdir -p "$BIN_DIR"
  ln -sf "$SRC" "$BIN_DIR/zj"
  say "${GREEN}Linked${RESET} $BIN_DIR/zj → $SRC"

  case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) say "${YELLOW}note:${RESET} $BIN_DIR is not on your PATH. Add it, e.g.:"
       say "      export PATH=\"$BIN_DIR:\$PATH\"" ;;
  esac
}

# Seed ~/.config/zj with starter orgs/remotes files (never clobber existing ones).
seed_config() {
  mkdir -p "$CONFIG_DIR"
  local name src dest
  for name in orgs remotes; do
    src="$SCRIPT_DIR/$name.example"
    dest="$CONFIG_DIR/$name"
    [ -f "$src" ] || continue
    if [ -e "$dest" ]; then
      ok "$name ${DIM}config exists → $dest${RESET}"
    else
      cp "$src" "$dest"
      ok "$name ${DIM}seeded → $dest${RESET}"
    fi
  done
  say "${DIM}  edit $CONFIG_DIR/orgs and $CONFIG_DIR/remotes to configure the picker${RESET}"
}

do_uninstall() {
  local link="$BIN_DIR/zj"
  if [ -L "$link" ] || [ -f "$link" ]; then
    rm -f "$link" && say "Removed $link"
  else
    say "Nothing to remove ($link not found)."
  fi
  say "${DIM}(dependencies installed in $BIN_DIR were left in place)${RESET}"
}

do_install() {
  command -v curl >/dev/null 2>&1 || die "curl is required."
  command -v tar  >/dev/null 2>&1 || die "tar is required."
  detect_platform
  arrow "detected: ${BOLD}${PLATFORM}${RESET} (${RUST_CPU})"

  mkdir -p "$BIN_DIR"
  say ""
  say "${BOLD}Dependencies${RESET} ${DIM}(prebuilt binaries from GitHub releases)${RESET}"

  local tool failed=0
  for tool in "${REQUIRED[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
      ok "$tool ${DIM}already installed${RESET}"
    else
      install_tool "$tool" || failed=$((failed + 1))
    fi
  done

  # fnox is optional: installed only with --with-fnox, otherwise just noted.
  if command -v fnox >/dev/null 2>&1; then
    ok "fnox ${DIM}already installed (optional)${RESET}"
  elif [ "$WITH_FNOX" = true ]; then
    install_tool fnox || say "  ${DIM}(fnox is optional — continuing without it)${RESET}"
  else
    say "  ${DIM}- fnox not installed (optional; pass --with-fnox for 1Password-backed tokens)${RESET}"
  fi

  say ""
  link_zj

  say ""
  say "${BOLD}Config${RESET} ${DIM}($CONFIG_DIR)${RESET}"
  seed_config

  if [ "$failed" -gt 0 ]; then
    say ""
    die "$failed required tool(s) could not be installed (see above)."
  fi
}

# --- dispatch ------------------------------------------------------------------

action=install
for arg in "$@"; do
  case "$arg" in
    install)         action=install ;;
    --symlink-only)  action=symlink ;;
    -u|--uninstall)  action=uninstall ;;
    --with-fnox)     WITH_FNOX=true ;;
    -h|--help|help)  usage 0 ;;
    *) say "Unknown option: $arg"; usage 1 ;;
  esac
done

case "$action" in
  install)   do_install ;;
  symlink)   link_zj ;;
  uninstall) do_uninstall ;;
esac

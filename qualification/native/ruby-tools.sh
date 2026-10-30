#!/usr/bin/env bash
# Select the runner's Homebrew Ruby and prepare only the repository's locked iOS tools.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
brew_bin="$(command -v brew || ls /opt/homebrew/bin/brew /usr/local/bin/brew 2>/dev/null | head -1)"
ruby_prefix="$([ -n "$brew_bin" ] && "$brew_bin" --prefix ruby 2>/dev/null || true)"
ruby_bin="$ruby_prefix/bin"
[[ -x "$ruby_bin/ruby" ]] || { echo 'Homebrew Ruby is required on the macOS runner.' >&2; exit 1; }
export PATH="$ruby_bin:$PATH"
export BUNDLE_PATH="$HOME/.cache/wuselwall/bundle"
export BUNDLE_FROZEN=true
export BUNDLE_GEMFILE="$repo_root/app/ios/Gemfile"
ruby --version
if ! bundle check; then bundle install; fi
bundle check
if [[ -n "${GITHUB_PATH:-}" ]]; then printf '%s\n' "$ruby_bin" >> "$GITHUB_PATH"; fi
if [[ -n "${GITHUB_ENV:-}" ]]; then
  printf 'BUNDLE_PATH=%s\nBUNDLE_FROZEN=true\nBUNDLE_GEMFILE=%s\n' "$BUNDLE_PATH" "$BUNDLE_GEMFILE" >> "$GITHUB_ENV"
fi

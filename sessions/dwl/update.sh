#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

if [[ -d .git ]] && git remote get-url origin >/dev/null 2>&1; then
  if [[ -z "$(git status --porcelain)" ]]; then
    echo "==> Updating repository"
    git pull --ff-only
  else
    echo "==> Local changes detected; skipping git pull"
  fi
fi

exec bash "$ROOT/install-fedora.sh"

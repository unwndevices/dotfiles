#!/bin/bash
# Symlink files from repo home/ into $HOME. Idempotent: safe to re-run.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_SRC="${REPO_ROOT}/home"

if [ ! -d "$HOME_SRC" ]; then
    echo "No home/ dir in repo." >&2
    exit 1
fi

for f in "$HOME_SRC"/*; do
    [ -e "$f" ] || continue
    name="$(basename "$f")"
    target="${HOME}/${name}"
    if [ -L "$target" ] && [ "$(readlink -f "$target")" = "$(readlink -f "$f")" ]; then
        echo "[skip] $name (already linked)"
        continue
    fi
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        echo "[backup] $name -> ${name}.bak"
        mv "$target" "${target}.bak"
    fi
    ln -sf "$f" "$target"
    echo "[link] $name -> $target"
done

echo "Done."

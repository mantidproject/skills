#!/usr/bin/env bash
#
# Install skills from this repository into a target checkout's .claude/skills/.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/skills"
MODE="symlink"

usage() {
    cat <<'USAGE'
Usage: install.sh [--copy] TARGET_REPO [SKILL...]

  --copy   copy the skill instead of symlinking it (default: symlink, so that
           a pull in mantid-skills updates every checkout)

With no SKILL names, installs every skill in the repository.
USAGE
}

[[ $# -gt 0 ]] || { usage >&2; exit 2; }
if [[ "$1" == "--copy" ]]; then MODE="copy"; shift; fi
if [[ "$1" == "-h" || "$1" == "--help" ]]; then usage; exit 0; fi
[[ $# -gt 0 ]] || { usage >&2; exit 2; }

TARGET="$1"; shift
[[ -d "$TARGET" ]] || { echo "no such directory: $TARGET" >&2; exit 1; }
TARGET="$(cd "$TARGET" && pwd)"

if [[ $# -gt 0 ]]; then
    skills=("$@")
else
    skills=()
    for d in "$SRC"/*/; do skills+=("$(basename "$d")"); done
fi

dest="${TARGET}/.claude/skills"
mkdir -p "$dest"

for skill in "${skills[@]}"; do
    from="${SRC}/${skill}"
    if [[ ! -f "${from}/SKILL.md" ]]; then
        echo "skipping ${skill}: no SKILL.md" >&2
        continue
    fi
    to="${dest}/${skill}"
    rm -rf "$to"
    if [[ "$MODE" == "copy" ]]; then
        cp -R "$from" "$to"
    else
        ln -s "$from" "$to"
    fi
    echo "installed ${skill} -> ${to}"
done

echo
echo "Run /skills in Claude Code from ${TARGET} to confirm."

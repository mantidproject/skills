#!/usr/bin/env bash
#
# Report build / CI / configuration differences between an ornl-next branch and
# main, and optionally the upstream commits responsible for them.
#
# This script owns THE path list. Nothing else should hardcode one.

set -euo pipefail

REMOTE="${ORNL_REMOTE:-}"
MAIN_REF=""
ORNL_REF=""
MODE="diff"
SINCE=""

usage() {
    cat <<'USAGE'
Usage: check-paths.sh [options]

  --remote NAME  git remote holding the mantidproject repository. Defaults to
                 $ORNL_REMOTE, else the remote whose URL is mantidproject/mantid,
                 else "upstream".
  --main REF     full ref for upstream main       (default: <remote>/main)
  --ornl REF     full ref for the ornl-next work  (default: <remote>/ornl-next)
  --log          list upstream commits touching the config paths instead of
                 listing differing files
  --since REF    with --log, start from REF       (default: last full release tag)
  --paths        print the path list and exit
  --remotes      print candidate remotes and which one would be used, then exit
  -h, --help     this message

--main and --ornl are complete refs and override --remote for that branch,
so a local or contributor branch can be checked directly:

  check-paths.sh --ornl my-reconciliation-branch

Exit status: 0 if the config paths are in sync, 1 if they differ.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --remote)  REMOTE="$2"; shift 2 ;;
        --main)    MAIN_REF="$2"; shift 2 ;;
        --ornl)    ORNL_REF="$2"; shift 2 ;;
        --since)   SINCE="$2"; shift 2 ;;
        --log)     MODE="log"; shift ;;
        --paths)   MODE="paths"; shift ;;
        --remotes) MODE="remotes"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

cd "$(git rev-parse --show-toplevel)"

# Remotes pointing at the canonical repository, over ssh or https, with or
# without a .git suffix. Contributor forks are deliberately not matched.
mantid_remotes() {
    git remote -v \
        | awk '$3 == "(fetch)" && $2 ~ /[:\/]mantidproject\/mantid(\.git)?$/ { print $1 }' \
        | sort -u
}

resolve_remote() {
    if [[ -n "$REMOTE" ]]; then
        if ! git remote get-url "$REMOTE" >/dev/null 2>&1; then
            echo "no such git remote: ${REMOTE}" >&2
            echo "available remotes: $(git remote | tr '\n' ' ')" >&2
            exit 2
        fi
        echo "$REMOTE"; return
    fi

    local found
    found="$(mantid_remotes | head -1)"
    if [[ -n "$found" ]]; then echo "$found"; return; fi

    if git remote get-url upstream >/dev/null 2>&1; then echo "upstream"; return; fi

    echo "cannot determine which remote holds mantidproject/mantid." >&2
    echo "available remotes: $(git remote | tr '\n' ' ')" >&2
    echo "pass --remote NAME, or set ORNL_REMOTE." >&2
    exit 2
}

if [[ "$MODE" == "remotes" ]]; then
    echo "remotes matching mantidproject/mantid:"
    mantid_remotes | sed 's/^/  /'
    echo "would use: $(resolve_remote)"
    exit 0
fi

# Only resolve a remote for the refs that were not given in full.
if [[ -z "$MAIN_REF" || -z "$ORNL_REF" ]]; then
    resolved="$(resolve_remote)"
    : "${MAIN_REF:=${resolved}/main}"
    : "${ORNL_REF:=${resolved}/ornl-next}"
fi

for ref in "$MAIN_REF" "$ORNL_REF"; do
    git rev-parse --verify --quiet "${ref}^{commit}" >/dev/null || {
        echo "cannot resolve ref: ${ref}" >&2
        echo "fetch first, or pass --remote / --main / --ornl." >&2
        exit 2
    }
done

# Build / CI / configuration surface that ornl-next must track from main.
#
# Only git-tracked paths belong here. Untracked local directories (.reuse,
# .envrc, .vscode, .opencode) and build artifact directories produce no diff
# and only slow the scan down.
PATHS=(
    # environment / dependency pinning
    pixi.lock
    pixi.toml
    .pixi-version          # NOTE: the glob pixi.* does NOT match this
    conda/
    external/
    DEPENDENCY_LICENSES.md

    # CI and build configuration
    .github/
    buildconfig/
    installers/
    images/
    tools/
    CMakeLists.txt
    CMakePresets.json
    pyproject.toml
    setup.py

    # test harness tooling (not the tests themselves)
    Testing/PerformanceTests/
    Testing/SystemTests/lib/
    Testing/SystemTests/scripts/
    Testing/Tools/

    # linting / formatting / repo hygiene
    .clang-format
    .clang-tidy
    .cmake-format.json
    .git-blame-ignore-revs
    .gitattributes
    .gitignore
    .grype.yaml
    .pre-commit-config.yaml
    .rstcheck.project.cfg

    # repo-level prose that upstream maintains
    AGENTS.md
    CITATION.cff
    README.md
    SECURITY.md
    dev-docs/source/conf.py
    docs/source/conf.py
)

# Generated file: it is rewritten on every build, so it always differs and
# never carries real upstream intent.
exclude() { grep -v 'CppCheck_Suppressions.txt.in' || true; }

last_release_tag() {
    # A "full release" is vX.Y.Z exactly. This excludes release candidates
    # (v6.16.1.2rc1), patch-of-patch tags (v6.16.1.1) and the date-stamped
    # nightly tags (v6.16.20260828.1750).
    git tag --list 'v*' --sort=-v:refname \
        | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
        | head -1
}

case "$MODE" in
    paths)
        printf '%s\n' "${PATHS[@]}"
        ;;
    log)
        [[ -n "$SINCE" ]] || SINCE="$(last_release_tag)"
        echo "# commits on ${MAIN_REF} touching config paths since ${SINCE}" >&2
        git log --topo-order --reverse --format='%h %ad %s' --date=short \
            "${SINCE}..${MAIN_REF}" -- "${PATHS[@]}" | exclude
        ;;
    diff)
        # Two explicit refs: compares committed trees only, so uncommitted work
        # and untracked files in the working tree cannot create false hits.
        differing="$(git diff --name-only "$ORNL_REF" "$MAIN_REF" -- "${PATHS[@]}" | exclude)"
        if [[ -z "$differing" ]]; then
            echo "In sync: no configuration differences between ${ORNL_REF} and ${MAIN_REF}."
            exit 0
        fi
        echo "Configuration files on ${MAIN_REF} not yet reflected in ${ORNL_REF}:"
        printf '%s\n' "$differing"
        exit 1
        ;;
esac

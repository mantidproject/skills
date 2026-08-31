#!/usr/bin/env bash
#
# Report build / CI / configuration differences between an ornl-next branch and
# main, and optionally the upstream commits responsible for them.
#
# This script owns THE path list. Nothing else should hardcode one.

set -euo pipefail

MAIN_REF="upstream/main"
ORNL_REF="upstream/ornl-next"
MODE="diff"
SINCE=""

usage() {
    cat <<'USAGE'
Usage: check-paths.sh [options]

  --main REF     ref holding upstream main       (default: upstream/main)
  --ornl REF     ref holding the ornl-next work  (default: upstream/ornl-next)
  --log          list upstream commits touching the config paths instead of
                 listing differing files
  --since REF    with --log, start from REF      (default: last full release tag)
  --paths        print the path list and exit
  -h, --help     this message

Exit status: 0 if the config paths are in sync, 1 if they differ.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --main)  MAIN_REF="$2"; shift 2 ;;
        --ornl)  ORNL_REF="$2"; shift 2 ;;
        --since) SINCE="$2"; shift 2 ;;
        --log)   MODE="log"; shift ;;
        --paths) MODE="paths"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

cd "$(git rev-parse --show-toplevel)"

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
        exit 0
        ;;
    log)
        [[ -n "$SINCE" ]] || SINCE="$(last_release_tag)"
        echo "# commits on ${MAIN_REF} touching config paths since ${SINCE}" >&2
        git log --topo-order --reverse --format='%h %ad %s' --date=short \
            "${SINCE}..${MAIN_REF}" -- "${PATHS[@]}" | exclude
        exit 0
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

#!/usr/bin/env bash
#
# create-nudge-bump-pr.sh -- emit a script that opens a single PR bumping all
# three operand images to their latest Konflux-promoted digests.
#
# Konflux nudges each operand bump (operator, agent, daemon) in as a separate
# PR. Merging them one at a time lets their push pipelines race and the
# resulting snapshot order can come out wrong, and a nudge PR is often already
# stale by the time you merge it. This sidesteps both: it resolves the current
# lastPromotedImage for all three components straight from the cluster and
# writes a script that bumps them in one commit and one PR. One PR means one
# push pipeline and one snapshot -- nothing left to order, and the digests are
# as fresh as the cluster, not as fresh as whenever the nudge PR was cut.
#
# It does not touch your repo or GitHub. It prints a shell script to stdout
# with the digests frozen in; progress goes to stderr. Redirect, read, run:
#
#   ./hack/openshift/create-nudge-bump-pr.sh zstream --base release-0.6 \
#       --base-remote downstream --push-remote origin > foo.sh
#   less foo.sh        # the digests and every git/gh command are right there
#   bash foo.sh        # only this changes anything
#
# Resolving the digests reuses hack/openshift/sync-nudge-files.sh, so the same
# prerequisite applies: oc logged into the Konflux cluster with access to the
# ocp-bpfman-tenant namespace. The emitted script needs only git and gh.
#
# Remote names are per-clone, so you must name them: --base-remote is where
# the authoritative base branch lives (the openshift remote), --push-remote is
# where your branch goes (your fork). They are frequently different.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
sync_script="${script_dir}/sync-nudge-files.sh"
nudge_rel="hack/konflux/images"
nudge_dir="${repo_root}/${nudge_rel}"

pr_repo="openshift/bpfman-operator"
stream=""
base=""
base_remote=""
push_remote=""
head_owner=""

usage() {
    cat >&2 <<'EOF'
usage: create-nudge-bump-pr.sh <ystream|zstream> --base-remote NAME \
                               --push-remote NAME [options] > foo.sh

  <ystream|zstream>     which stream to bump

required:
      --base-remote NAME  git remote holding the authoritative base branch
                          (the openshift remote)
      --push-remote NAME  git remote the emitted script pushes to (your fork)

options:
  -b, --base BRANCH       target branch (default: main for ystream; required
                          for zstream, e.g. release-0.6)
  -H, --head OWNER        owner namespace for the PR head, used as
                          --head OWNER:branch (default: derived from the
                          push remote's URL)
      --repo OWNER/REPO   repository the emitted script opens the PR against
                          (default: openshift/bpfman-operator)
  -h, --help              this help

examples:
  The base branch lives in the openshift/bpfman-operator remote; the PR
  pushes from your fork. With remotes named upstream (openshift) and
  origin (your fork), that is --base-remote upstream --push-remote origin.
  (A separate bpfman remote for bpfman/bpfman-operator is not used here.)

  # ystream: bump main
  create-nudge-bump-pr.sh ystream \
      --base-remote upstream --push-remote origin > bump.sh

  # zstream: bump a release branch (--base is required)
  create-nudge-bump-pr.sh zstream --base release-0.6 \
      --base-remote upstream --push-remote origin > bump.sh

  # then review the emitted script and run it
  less bump.sh
  bash bump.sh

The script is written to stdout; redirect it, read it, then run it. Nothing
here touches your repo or GitHub -- only running the emitted script does.

prerequisites:
  - run from a bpfman-operator checkout with hack/konflux/images clean
  - oc logged into the Konflux cluster (ocp-bpfman-tenant) for the digest lookup
EOF
    exit "${1:-2}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        ystream|zstream) stream="$1"; shift ;;
        -b|--base)        base="$2"; shift 2 ;;
        --base-remote)    base_remote="$2"; shift 2 ;;
        --push-remote)    push_remote="$2"; shift 2 ;;
        -H|--head)        head_owner="$2"; shift 2 ;;
        --repo)           pr_repo="$2"; shift 2 ;;
        -h|--help)        usage 0 ;;
        *) echo "unknown argument: $1" >&2; usage 2 ;;
    esac
done

[[ -n "$stream" ]]      || { echo "error: stream (ystream|zstream) is required" >&2; usage 2; }
[[ -n "$base_remote" ]] || { echo "error: --base-remote is required" >&2; usage 2; }
[[ -n "$push_remote" ]] || { echo "error: --push-remote is required" >&2; usage 2; }

# ystream tracks main; zstream tracks a specific release branch, and there can
# be more than one active, so do not guess it.
if [[ -z "$base" ]]; then
    if [[ "$stream" == "ystream" ]]; then
        base="main"
    else
        echo "error: zstream needs an explicit --base (e.g. release-0.6)" >&2
        exit 2
    fi
fi

[[ -x "$sync_script" ]] || { echo "error: $sync_script not found or not executable" >&2; exit 1; }

cd "$repo_root"

# Resolving digests rewrites the image pins in place; refuse if they are dirty
# so the restore below is exact. A dirty tree elsewhere is irrelevant.
if [[ -n "$(git status --porcelain -- "$nudge_dir")" ]]; then
    echo "error: uncommitted changes under ${nudge_rel}; commit or stash first" >&2
    exit 1
fi

# Default the PR head owner to whoever owns the push remote.
if [[ -z "$head_owner" ]]; then
    head_owner="$(git remote get-url "$push_remote" \
        | sed -E 's#\.git$##; s#.*[:/]([^/]+)/[^/]+$#\1#')"
    [[ -n "$head_owner" ]] || { echo "error: could not derive head owner from ${push_remote}; pass --head" >&2; exit 1; }
fi

# Resolve the three digests by running the existing sync against the cluster,
# reading the rewritten pins, then restoring the working tree. Send the sync's
# own chatter to stderr so stdout stays pure script.
echo "Resolving latest promoted digests for ${stream} from the cluster..." >&2
if ! "$sync_script" "$stream" >&2; then
    echo "error: sync-nudge-files.sh failed; is oc logged into the Konflux cluster?" >&2
    git checkout --quiet -- "$nudge_dir" 2>/dev/null || true
    exit 1
fi
operator_line="$(cat "${nudge_dir}/bpfman-operator.txt")"
agent_line="$(cat "${nudge_dir}/bpfman-agent.txt")"
daemon_line="$(cat "${nudge_dir}/bpfman.txt")"
git checkout --quiet -- "$nudge_dir"

branch="nudge-bump-${stream}-${base}-$(date +%Y%m%d-%H%M%S)"

commit_title="Bump ${stream} operand images to latest promoted digests"
commit_body="Set bpfman-operator, bpfman-agent and bpfman-daemon to their current
Konflux lastPromotedImage for the ${stream} stream, replacing the individual
konflux-nudge PRs with one deterministic bump so a single push pipeline
produces a single consistent snapshot."

pr_body="Consolidated ${stream} operand bump: bpfman-operator, bpfman-agent and
bpfman-daemon set to their current Konflux lastPromotedImage, resolved from the
cluster rather than from the individual konflux-nudge PRs. One PR means one push
pipeline and one snapshot, so there is no merge order to get wrong, and the
digests are current as of PR creation. This is the manual replacement for
per-operand Konflux nudging."

# Everything from here is the emitted script, on stdout.
emit() { printf '%s\n' "$1"; }

emit '#!/usr/bin/env bash'
emit "# Bump ${stream} operand images to their latest Konflux-promoted digests."
emit "# Generated by hack/openshift/create-nudge-bump-pr.sh on $(date -u +%Y-%m-%dT%H:%M:%SZ)."
emit '# Review the digests and commands below, then run with: bash foo.sh'
emit 'set -euo pipefail'
emit ''
emit '# Operand pins are written under hack/konflux/images using paths relative'
emit '# to the repository root, so this must run from there.'
emit 'toplevel="$(git rev-parse --show-toplevel 2>/dev/null)" || {'
emit "    echo 'error: not inside a git repository.' >&2"
emit '    exit 1'
emit '}'
emit 'if [[ ! "$PWD" -ef "$toplevel" ]]; then'
emit '    echo "error: run this from the repository root: cd $toplevel" >&2'
emit '    exit 1'
emit 'fi'
emit ''
emit 'start_ref="$(git symbolic-ref --quiet --short HEAD || git rev-parse HEAD)"'
emit "git fetch ${base_remote} ${base}"
emit "git checkout -b ${branch} FETCH_HEAD"
emit ''
emit "printf '%s\\n' '${operator_line}' > ${nudge_rel}/bpfman-operator.txt"
emit "printf '%s\\n' '${agent_line}' > ${nudge_rel}/bpfman-agent.txt"
emit "printf '%s\\n' '${daemon_line}' > ${nudge_rel}/bpfman.txt"
emit "git add ${nudge_rel}"
emit ''
emit 'if git diff --cached --quiet; then'
emit "    echo 'Already at the latest promoted digests; nothing to bump.' >&2"
emit '    git checkout --quiet "$start_ref" 2>/dev/null || true'
emit "    git branch -D ${branch} >/dev/null 2>&1 || true"
emit '    exit 0'
emit 'fi'
emit ''
emit "git commit -m '${commit_title}' -m '${commit_body}'"
emit "git push ${push_remote} ${branch}"
emit "gh pr create --repo ${pr_repo} --base ${base} --head ${head_owner}:${branch} \\"
emit "    --title '${commit_title}' \\"
emit "    --body '${pr_body}'"

echo "Wrote bump script to stdout (branch ${branch}). Redirect it to a file, review, then run it." >&2

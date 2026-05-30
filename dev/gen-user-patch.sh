#!/usr/bin/env bash
# dev/gen-user-patch.sh — generate a CLEAN user patch from working-tree edits.
#
# WHY THIS EXISTS (retro 2026-05-28):
#   `cd vscode && git diff` does NOT give a usable user patch — the vscode/ baseline is
#   pristine upstream and ALL patches (base → windows → user) are applied as uncommitted
#   mods, so a plain diff bundles every patch plus your edits together. Producing a clean
#   single-purpose user patch meant hand-reconstructing the "post-base" state in a scratch
#   repo — done 3× by hand this session. This scripts that procedure.
#
# WHAT IT DOES:
#   For the file(s) you edited in vscode/, it rebuilds the exact state those files would be
#   in RIGHT BEFORE your new patch applies in the real build sequence — pristine upstream
#   + every base patch + every windows patch + every EXISTING user patch that sorts before
#   your target name (all with the same !!APP_NAME!! → Arclen substitution the build uses) —
#   then diffs your live edits against that. The result is a patch containing ONLY your edits,
#   correctly anchored, which it then validates by re-applying onto that exact baseline (the
#   real apply order, including user-patch dependencies that check-patches.sh can't simulate).
#
# Usage:
#   dev/gen-user-patch.sh <patches/user/NAME.patch> <vscode-relative-file> [more files...]
#
# Example (after editing vscode/src/vs/base/browser/fonts.ts):
#   dev/gen-user-patch.sh arclen-fonts src/vs/base/browser/fonts.ts
#
# Notes:
#   • File paths are relative to vscode/ (e.g. src/vs/...), matching the +++ b/ patch paths.
#   • The target NAME's sort position determines which existing user patches are treated as
#     "already applied" — name it the same way the build will sort it (arclen-*).
#   • Brand context is auto-placeholder-ized: any CONTEXT/REMOVED line our patch inherits
#     from a prior patch's brand substitution (e.g. "Arclen" that 00-brand wrote over "VS Code")
#     is rewritten back to its !!PLACEHOLDER!! form, so the patch applies in BOTH the real
#     (substituted) build AND check-patches.sh's non-substituted tree. This kills the
#     "brand-context placeholder trap" (retro 2026-05-30) at the source. Added (+) lines are
#     left verbatim — they are your deliberate content; write !!APP_NAME!! yourself if needed.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VSCODE="${REPO_ROOT}/vscode"
cd "${REPO_ROOT}"

green='\033[0;32m'; red='\033[0;31m'; cyan='\033[1;36m'; reset='\033[0m'
step() { printf '\n%b[gen-patch]%b %s\n' "$cyan" "$reset" "$1"; }
ok()   { printf '%b  ✓ %s%b\n' "$green" "$1" "$reset"; }
die()  { printf '%b  ✗ %s%b\n' "$red" "$1" "$reset" >&2; exit "${2:-1}"; }

# ─── Args ─────────────────────────────────────────────────────────────────────
[[ $# -ge 2 ]] || die "usage: dev/gen-user-patch.sh <patches/user/NAME.patch> <file> [file...]" 64

OUT_ARG="$1"; shift
# Normalize the output path to patches/user/NAME.patch
case "${OUT_ARG}" in
  patches/user/*) OUT="${OUT_ARG}" ;;
  */*)            OUT="${OUT_ARG}" ;;
  *)              OUT="patches/user/${OUT_ARG}" ;;
esac
[[ "${OUT}" == *.patch ]] || OUT="${OUT}.patch"
OUT_BASE="$(basename "${OUT}")"

FILES=("$@")
[[ -d "${VSCODE}/.git" ]] || die "vscode/ is not a git repo (run a build first?)" 2
for f in "${FILES[@]}"; do
  [[ -f "${VSCODE}/${f}" ]] || die "no such file in vscode/: ${f}" 2
done

# ─── Branding substitution values (same source the build uses) ────────────────
# Pull the literal export lines from dev/build.sh without running the rest of it.
eval "$(grep -E '^export (APP_NAME|ASSETS_REPOSITORY|BINARY_NAME|GH_REPO_PATH|ORG_NAME)=' dev/build.sh)"
APP_NAME="${APP_NAME:-Arclen}"
ASSETS_REPOSITORY="${ASSETS_REPOSITORY:-}"
BINARY_NAME="${BINARY_NAME:-arclen}"
GH_REPO_PATH="${GH_REPO_PATH:-}"
ORG_NAME="${ORG_NAME:-Arclen}"
APP_NAME_LC="$(printf '%s' "${APP_NAME}" | tr '[:upper:]' '[:lower:]')"
GLOBAL_DIRNAME="${APP_NAME_LC}"
TUNNEL_APP_NAME="${BINARY_NAME}-tunnel"
RELEASE_VERSION="${RELEASE_VERSION:-}"

substitute() {  # substitute !!PLACEHOLDER!! in-place, mirroring utils.sh apply_patch()
  sed -i -E \
    -e "s|!!APP_NAME!!|${APP_NAME}|g" \
    -e "s|!!APP_NAME_LC!!|${APP_NAME_LC}|g" \
    -e "s|!!ASSETS_REPOSITORY!!|${ASSETS_REPOSITORY}|g" \
    -e "s|!!BINARY_NAME!!|${BINARY_NAME}|g" \
    -e "s|!!GH_REPO_PATH!!|${GH_REPO_PATH}|g" \
    -e "s|!!GLOBAL_DIRNAME!!|${GLOBAL_DIRNAME}|g" \
    -e "s|!!ORG_NAME!!|${ORG_NAME}|g" \
    -e "s|!!RELEASE_VERSION!!|${RELEASE_VERSION}|g" \
    -e "s|!!TUNNEL_APP_NAME!!|${TUNNEL_APP_NAME}|g" \
    "$1"
}

to_lf() { sed -i 's/\r$//' "$1"; }   # the working tree often has mixed CRLF+LF (known
                                     # Windows gotcha); user patches are pure LF (and
                                     # check-patches.sh validates vs a fresh LF clone), so
                                     # normalize every scratch file to LF before diffing.

patch_touches() {  # $1=patch file — true if it touches any of FILES
  local p="$1" f
  for f in "${FILES[@]}"; do
    grep -q "^+++ b/${f}\$" "$p" 2>/dev/null && return 0
  done
  return 1
}

# ─── Build the ordered list of patches that run BEFORE ours ───────────────────
# Real build order: patches/*.patch → patches/windows/*.patch → patches/user/*.patch (each sorted).
PRIOR=()
while IFS= read -r p; do PRIOR+=("$p"); done < <(ls patches/*.patch          2>/dev/null | sort)
while IFS= read -r p; do PRIOR+=("$p"); done < <(ls patches/windows/*.patch  2>/dev/null | sort)
while IFS= read -r p; do
  b="$(basename "$p")"
  [[ "$b" == "$OUT_BASE" ]] && continue          # not ourselves
  [[ "$b" < "$OUT_BASE" ]] && PRIOR+=("$p")       # only user patches sorted before ours
done < <(ls patches/user/*.patch 2>/dev/null | sort)

# Keep only the ones that actually touch our target files.
APPLICABLE=()
for p in "${PRIOR[@]}"; do patch_touches "$p" && APPLICABLE+=("$p"); done

step "Target: ${OUT}   files: ${FILES[*]}"
if [[ ${#APPLICABLE[@]} -gt 0 ]]; then
  echo "  Prior patches forming the baseline for these files:"
  for p in "${APPLICABLE[@]}"; do echo "    $(basename "$p")"; done
else
  echo "  No prior patch touches these files → baseline = pristine upstream."
fi

# ─── Reconstruct the baseline in a scratch git repo ───────────────────────────
SCRATCH="${REPO_ROOT}/.genpatch"
rm -rf "${SCRATCH}"; mkdir -p "${SCRATCH}"
trap 'rm -rf "${SCRATCH}"' EXIT
git -C "${SCRATCH}" init -q
git -C "${SCRATCH}" config user.email gen@arclen.local
git -C "${SCRATCH}" config user.name  arclen-gen
git -C "${SCRATCH}" config core.autocrlf false

step "Seeding pristine upstream copies"
for f in "${FILES[@]}"; do
  mkdir -p "${SCRATCH}/$(dirname "$f")"
  git -C "${VSCODE}" show "HEAD:${f}" > "${SCRATCH}/${f}" \
    || die "could not read pristine HEAD:${f} from vscode/" 2
  to_lf "${SCRATCH}/${f}"
done
git -C "${SCRATCH}" add -A
git -C "${SCRATCH}" commit -q -m pristine
ok "pristine committed"

step "Replaying prior patches onto the baseline (substituted, scoped to target files)"
INCL=(); for f in "${FILES[@]}"; do INCL+=(--include="$f"); done
for p in "${APPLICABLE[@]}"; do
  tmp="${SCRATCH}/.replay.patch"
  cp "$p" "$tmp"; substitute "$tmp"
  if git -C "${SCRATCH}" apply "${INCL[@]}" --ignore-whitespace "$tmp" 2>"${SCRATCH}/.err"; then
    ok "applied $(basename "$p")"
  else
    echo "$(< "${SCRATCH}/.err")" | sed 's/^/      /'
    die "prior patch $(basename "$p") failed against the baseline — patch set may be out of sync with vscode/" 3
  fi
  rm -f "$tmp"
done
for f in "${FILES[@]}"; do to_lf "${SCRATCH}/${f}"; done   # patches may carry CRLF
git -C "${SCRATCH}" add -A
git -C "${SCRATCH}" commit -q -m baseline --allow-empty
ok "baseline committed"

# ─── Brand resolved→placeholder map (read from the prior patches themselves) ───
# WHY: check-patches.sh applies base patches WITHOUT placeholder substitution, while the
# baseline above is substituted (placeholders resolved to "Arclen"). Any CONTEXT/REMOVED
# line our patch inherits from a brand substitution therefore reads "Arclen" here but
# "!!APP_NAME!!" in check-patches' tree → the patch's context mismatches and check-patches
# cries "does not apply" on a patch the real build accepts (the "brand-context placeholder
# trap", retro 2026-05-30 — once ~15 min + a near-miss brand regression).
#
# The mapping comes straight from the SOURCE: every '+' added line of a prior patch that
# carries a !!PLACEHOLDER!! becomes, after substitution, a resolved line that appears in our
# baseline as context. So resolved=substitute(placeholder). We read those lines directly
# (no re-apply — an earlier attempt rebuilt a non-substituted baseline and got a FALSE map
# when a prior patch's raw replay partially failed). Lossless by construction; verified by a
# round-trip below.
step "Mapping brand placeholders from prior patches (to placeholder-ize context)"
BRANDMAP="${SCRATCH}/.brandmap"; : > "${BRANDMAP}"
SEP=$'\x1f'
if [[ ${#APPLICABLE[@]} -gt 0 ]]; then
  PH="${SCRATCH}/.ph"; RS="${SCRATCH}/.rs"
  # placeholder content lines: '+' adds that contain a !!...!! token (drop the +++ header).
  grep -h '^+' "${APPLICABLE[@]}" 2>/dev/null | grep -v '^+++ ' | grep '!!' | sed 's/^+//' | sort -u > "${PH}"
  if [[ -s "${PH}" ]]; then
    cp "${PH}" "${RS}"; substitute "${RS}"            # resolved = substitute(placeholder), line-aligned
    # key=resolved  value=placeholder ; keep only lines substitution actually changed.
    paste -d "${SEP}" "${RS}" "${PH}" | awk -F"${SEP}" 'NF==2 && $1!=$2' > "${BRANDMAP}"
  fi
fi
if [[ -s "${BRANDMAP}" ]]; then
  ok "brand placeholder lines available for context rewrite: $(grep -c . "${BRANDMAP}")"
else
  echo "  no brand placeholders in prior patches → nothing to placeholder-ize"
fi

# ─── Overlay live edits & diff ────────────────────────────────────────────────
step "Diffing your live vscode/ edits against the baseline"
for f in "${FILES[@]}"; do
  cp "${VSCODE}/${f}" "${SCRATCH}/${f}"
  to_lf "${SCRATCH}/${f}"
done
git -C "${SCRATCH}" diff > "${REPO_ROOT}/${OUT}"

if [[ ! -s "${REPO_ROOT}/${OUT}" ]]; then
  rm -f "${REPO_ROOT}/${OUT}"
  die "no differences found — did you actually edit ${FILES[*]} in vscode/ ? (nothing written)" 4
fi
added=$(grep -c '^+' "${REPO_ROOT}/${OUT}" || true)
removed=$(grep -c '^-' "${REPO_ROOT}/${OUT}" || true)
ok "wrote ${OUT}  (+${added} / -${removed} lines incl. headers)"

# ─── Validate against the real build sequence ─────────────────────────────────
# The generator already replayed base + windows + prior-user patches to build the
# baseline (dying if any failed), so a successful run already proves the pre-state is
# reachable. As a final guard, confirm the patch itself applies cleanly onto that exact
# baseline — this mirrors the real apply order INCLUDING user-patch dependencies, which
# check-patches.sh cannot (it only replays base patches).
step "Validating: patch applies onto the reconstructed baseline"
git -C "${SCRATCH}" reset -q --hard HEAD        # discard the overlay → back to baseline commit
if git -C "${SCRATCH}" apply --check --ignore-whitespace "${REPO_ROOT}/${OUT}"; then
  ok "applies cleanly onto base+windows+prior-user baseline"
else
  die "generated patch does not apply onto its own baseline (corruption?) — patch was still written" 5
fi

# ─── Placeholder-ize brand context (see mapping note above) ────────────────────
# Validation above used the literal-Arclen patch against the SUBSTITUTED baseline (so it
# must run first). Now rewrite brand-substituted CONTEXT/REMOVED lines to !!PLACEHOLDER!!
# form. Added (+) lines are left verbatim. We prove correctness by ROUND-TRIP: substituting
# the placeholder form must reproduce the already-validated literal form byte-for-byte —
# which means the real build (substitutes user patches → literal, validated) AND
# check-patches.sh (no subst → placeholder, matches the no-subst tree) both apply it.
if [[ -s "${BRANDMAP}" ]]; then
  step "Placeholder-izing brand context → !!PLACEHOLDER!! form"
  cp "${REPO_ROOT}/${OUT}" "${SCRATCH}/.out.literal"     # fallback if the round-trip regresses
  awk -v mapfile="${BRANDMAP}" -v sep="${SEP}" '
    BEGIN { while ((getline line < mapfile) > 0) { i=index(line,sep); if(i>0){ map[substr(line,1,i-1)]=substr(line,i+1) } } }
    /^diff / || /^index / || /^--- / || /^\+\+\+ / || /^@@/ { print; next }   # headers untouched
    /^ / || /^-/ { p=substr($0,1,1); r=substr($0,2); if (r in map) { print p map[r]; next } print; next }
    { print }
  ' "${SCRATCH}/.out.literal" > "${REPO_ROOT}/${OUT}"

  # Round-trip: substitute(placeholder form) must equal the validated literal form.
  cp "${REPO_ROOT}/${OUT}" "${SCRATCH}/.rt"; substitute "${SCRATCH}/.rt"
  if diff -q "${SCRATCH}/.rt" "${SCRATCH}/.out.literal" >/dev/null 2>&1; then
    n=$(grep -c '!!' "${REPO_ROOT}/${OUT}" || true)
    ok "round-trips to the validated literal form (${n} placeholder line(s)) → applies in both build & check-patches.sh"
  else
    cp "${SCRATCH}/.out.literal" "${REPO_ROOT}/${OUT}"
    printf '%b  ! placeholder round-trip mismatch — kept the literal-Arclen patch (safe fallback)%b\n' "$red" "$reset"
  fi
fi

# Clear the promoted files from the live-edits ledger (written by the arclen-track-edits
# PostToolUse hook) so the destructive-build guard stops flagging them — they're now in a patch.
LEDGER="${REPO_ROOT}/.claude/.live-edits"
if [[ -f "${LEDGER}" ]]; then
  for f in "${FILES[@]}"; do
    grep -vxF "$f" "${LEDGER}" > "${LEDGER}.tmp" 2>/dev/null || true
    mv -f "${LEDGER}.tmp" "${LEDGER}" 2>/dev/null || true
  done
  [[ -s "${LEDGER}" ]] || rm -f "${LEDGER}"   # tidy up when empty
fi

if [[ ${#APPLICABLE[@]} -gt 0 ]] && printf '%s\n' "${APPLICABLE[@]}" | grep -q '/user/'; then
  echo "  note: this patch depends on a prior USER patch, so check-patches.sh (base-only)"
  echo "        cannot validate it — the baseline check above is the authoritative one."
else
  echo "  tip: cross-check against a fresh upstream clone with:  bash check-patches.sh ${OUT}"
fi
printf '\n%b✓ %s is clean and validated%b\n' "$green" "${OUT}" "$reset"

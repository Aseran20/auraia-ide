#!/usr/bin/env bash
# dev/check-patch-collisions.sh — static lint: catch two USER patches that contain the SAME hunk
# (an identical context+removed block on the same file). That is a COLLISION: patches apply in
# sequence, so whichever lands second can't find the (already-removed) lines and dies with
# "patch does not apply" — aborting the build at the patch phase (~2-3 min in, after clone+npm).
#
# WHY THIS EXISTS (retro 2026-05-31):
#   arclen-rebrand-preferences.patch was generated carrying two hunks BYTE-IDENTICAL to ones in
#   arclen-trim-gear-menu.patch (gen-user-patch.sh swallowed another patch's hunks). The full build
#   failed at "git apply ... arclen-trim-gear-menu.patch: patch does not apply". check-patches.sh
#   could NOT catch it: it tests each patch against PRISTINE upstream in ISOLATION, so a clash that
#   only exists when both are applied in sequence is structurally invisible to it. This <1s static
#   check front-runs the 16-min build — fail cheap, not at minute 3 of a from-scratch build.
#
#   It is COMPLEMENTARY to check-patches' "⚠ conditional" detection (2026-05-30): that flags a
#   DEPENDENCY (patch B's context needs patch A applied first — different content, applies fine in
#   order). This flags a COLLISION (two patches carry the SAME hunk — order can't save them).
#
# PRECISION — why HUNK bodies, not lines: an earlier line-content version cried wolf, flagging two
#   patches that both remove a generic line (`title: {`, `content: {`, `when: '!isWeb',`) at DIFFERENT
#   locations — those apply fine. A whole identical hunk body (context + the -/+ lines, ignoring the
#   shiftable `@@ -a,b +c,d @@` header) only matches when the patches truly target the same block, so
#   it has no false positives by construction: if two patches share an identical removal block, the
#   second genuinely cannot apply.
#
# Exit: 0 = no duplicated hunks | 1 = collision(s) found.
# Usage: dev/check-patch-collisions.sh
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$REPO_ROOT/patches/user"

red() { printf '\033[0;31m%s\033[0m\n' "$1"; }
grn() { printf '\033[0;32m%s\033[0m\n' "$1"; }
ylw() { printf '\033[0;33m%s\033[0m\n' "$1"; }

US=$'\x1f'   # record/line separator — never appears in source lines

# key = "<file>US<hunk-body>" (body = hunk's context/-/+ lines joined by US, @@ header dropped,
#                              trailing whitespace stripped, only hunks with >=1 removed line)
# val = space-separated list of patch basenames carrying that exact hunk
declare -A HUNK2PATCHES
# remember a human sample (first removed line) per key, for the report
declare -A HUNK_SAMPLE

shopt -s nullglob
patches=( "$DIR"/*.patch )
shopt -u nullglob
if (( ${#patches[@]} == 0 )); then ylw "no patches in $DIR — nothing to check"; exit 0; fi

for p in "${patches[@]}"; do
  pname="$(basename "$p")"
  # awk emits one record per hunk-with-a-removal:  <file>\x1f<body>\x1f<first-removed-line>
  # records are newline-terminated; body's internal newlines are encoded as \x1f.
  while IFS= read -r rec; do
    [[ -z "$rec" ]] && continue
    file="${rec%%${US}*}"; tail="${rec#*${US}}"
    body="${tail%${US}*}"; sample="${tail##*${US}}"
    key="${file}${US}${body}"
    cur="${HUNK2PATCHES[$key]:-}"
    case " $cur " in
      *" $pname "*) : ;;                                   # same patch (don't pair with itself)
      *) HUNK2PATCHES[$key]="${cur:+$cur }$pname" ;;
    esac
    HUNK_SAMPLE[$key]="$file${US}$sample"
  done < <(awk -v US=$'\x1f' '
    function flush(   first) {
      if (inhunk && minus>0) {
        first=""
        n=split(body, arr, US)
        for (k=1;k<=n;k++) { if (substr(arr[k],1,1)=="-") { first=substr(arr[k],2); break } }
        print file US body US first
      }
      inhunk=0; body=""; minus=0
    }
    /^diff --git/ { flush(); file=""; next }
    /^\+\+\+ /    { flush(); f=$2; sub(/^[ab]\//,"",f); file=f; next }
    /^---/        { next }
    /^@@/         { flush(); inhunk=1; next }               # drop the shiftable @@ header itself
    {
      if (inhunk) {
        c=substr($0,1,1)
        if (c=="-"||c=="+"||c==" ") {
          l=$0; gsub(/[ \t]+$/,"",l)                        # normalize trailing whitespace
          body = body (body==""?"":US) l
          if (c=="-") minus++
        } else { flush() }                                  # "\ No newline at end of file" etc.
      }
    }
    END { flush() }
  ' "$p")
done

fails=0
for key in "${!HUNK2PATCHES[@]}"; do
  # shellcheck disable=SC2206
  ps=( ${HUNK2PATCHES[$key]} )
  (( ${#ps[@]} < 2 )) && continue
  fails=$(( fails + 1 ))
  smp="${HUNK_SAMPLE[$key]}"
  file="${smp%%${US}*}"; firstline="${smp#*${US}}"
  red "✗ COLLISION: $(printf '%s ⇄ %s' "${ps[0]}" "${ps[*]:1}")"
  printf '    same file  : %s\n' "$file"
  printf '    same hunk  : both carry an identical removal block, e.g. "-%s"\n' "${firstline:0:90}"
  printf '    → whichever applies second fails "patch does not apply".\n'
done

echo
if (( fails > 0 )); then
  red "✗ ${fails} duplicated-hunk collision(s) across ${#patches[@]} user patches."
  echo "  Regenerate the offending patch so only ONE patch owns that hunk (dev/gen-user-patch.sh),"
  echo "  or hand-delete the duplicated hunk from the patch that shouldn't carry it."
  exit 1
fi
grn "✓ no duplicated-hunk collisions across ${#patches[@]} user patches."
exit 0

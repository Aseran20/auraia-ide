#!/usr/bin/env bash
# dev/build-safe.sh — anti-crash wrapper around dev/build-checked.sh.
#
# WHY THIS EXISTS (2026-05-31): a full local build OOM-crashed the PC during the gulp COMPILE
# phase — the upstream default gives the build node proc an 8 GB heap (NODE_OPTIONS), and with
# parallel esbuild/native workers + everything else running (e.g. a ~2.5 GB MCP-server swarm,
# editors), total RAM was exceeded → hard crash. This wrapper caps the build's memory footprint
# to a fraction of PHYSICAL RAM and throttles node-gyp parallelism: a little slower, much more
# STABLE. dev/build.sh and build.sh now honor a caller-set NODE_OPTIONS, so this sticks.
#
# It REDUCES crash risk; it does not guarantee zero crash — close other RAM hogs first
# (dev/dev-cleanup.sh sweeps dev junk; consider closing spare editor windows / MCP servers).
#
# All args pass through to build-checked.sh:
#   dev/build-safe.sh         # cold full build, throttled
#   dev/build-safe.sh -s      # WARM build (reuses node_modules via the npm-ci guard — fast)
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$REPO_ROOT"

# ── total physical RAM (MB): msys2 /proc/meminfo first, then Windows wmic, else assume 16 GB ──
RAM_MB=""
if [[ -r /proc/meminfo ]]; then
  RAM_MB=$(( $(awk '/MemTotal/{print $2}' /proc/meminfo 2>/dev/null || echo 0) / 1024 ))
fi
if [[ -z "${RAM_MB}" || "${RAM_MB}" -lt 1024 ]]; then
  bytes=$(wmic ComputerSystem get TotalPhysicalMemory 2>/dev/null | tr -dc '0-9' || true)
  [[ -n "${bytes:-}" ]] && RAM_MB=$(( bytes / 1024 / 1024 ))
fi
[[ -z "${RAM_MB}" || "${RAM_MB}" -lt 1024 ]] && RAM_MB=16384

# heap = 40% of physical RAM, clamped to [4096, 6144] MB. The cap is BELOW upstream's 8192 on
# purpose: leave headroom for parallel esbuild/native workers + your other apps (MCP swarm,
# editors) so the machine doesn't OOM-crash. If the build instead dies with a clean
# "JavaScript heap out of memory", bump it: NODE_OPTIONS=--max-old-space-size=8192 dev/build-safe.sh
HEAP=$(( RAM_MB * 40 / 100 ))
(( HEAP < 4096 )) && HEAP=4096
(( HEAP > 6144 )) && HEAP=6144
export NODE_OPTIONS="--max-old-space-size=${HEAP}"

# node-gyp / native-rebuild parallelism: a quarter of the cores, clamped to [2, 4] — keeps the
# cold-build native-rebuild storm from saturating CPU+RAM at once.
CORES="${NUMBER_OF_PROCESSORS:-4}"
JOBS=$(( CORES / 4 )); (( JOBS < 2 )) && JOBS=2; (( JOBS > 4 )) && JOBS=4
export JOBS npm_config_jobs="${JOBS}"

printf '\033[1;36m[build-safe]\033[0m RAM=%sMB → NODE_OPTIONS=%s, JOBS=%s (cores=%s)\n' \
  "${RAM_MB}" "${NODE_OPTIONS}" "${JOBS}" "${CORES}"
echo  "[build-safe] tip: free RAM first — dev/dev-cleanup.sh, and close spare editors / MCP servers."
echo  "[build-safe] → dev/build-checked.sh $*"
exec bash "${REPO_ROOT}/dev/build-checked.sh" "$@"

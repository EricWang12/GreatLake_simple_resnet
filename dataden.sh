#!/usr/bin/env bash
# Mirror a *folder* from Great Lakes -> Data Den, preserving the full path
# under Data Den's /coe-jungaocv/wzn/ hierarchy.
#
# Example:
#   SRC  = /nfs/turbo/coe-jungaocv/wzn/workspace/AffU/third_party/sonata
#   DEST = /coe-jungaocv/wzn/workspace/AffU/third_party/sonata  (on Data Den)
#
# Requirements: globus CLI, two bookmarks:
#   - Source (default: turbo)           -> points at .../wzn/
#   - Destination (default: dataden-jungaocv) -> points at /coe-jungaocv/
#
# Env overrides:
#   SRC_BM (default: turbo)
#   DST_BM (default: dataden-jungaocv)
#   MIRROR_ROOT (default: none)  # top-level folder on Data Den to mirror under
#
# Usage:
#   ./upload_fullpath_to_dataden.sh <folder_path> [--dry-run]

set -euo pipefail

SRC_BM="${SRC_BM:-gl}"
DST_BM="${DST_BM:-dd-wzn}"
# MIRROR_ROOT="${MIRROR_ROOT:-wzn}"

usage() {
  echo "Usage: $0 <folder_path> [<remote_subpath>] [--dry-run]"
  echo "Env: SRC_BM=$SRC_BM DST_BM=$DST_BM"
  exit 1
}

[[ $# -lt 1 ]] && usage
DRY_RUN=0
UPLOAD_PATH_RAW=""
FOLDER_PATH="$1"; shift || true
# Optional second positional argument as remote subpath (must not start with '-')
if [[ $# -gt 0 && "${1:0:1}" != "-" ]]; then
  UPLOAD_PATH_RAW="$1"; shift
fi
# Remaining optional flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|-d) DRY_RUN=1; shift;;
    *) echo "Unknown arg: $1"; usage;;
  esac
done

# Resolve absolute local path and verify it's a directory
if command -v realpath >/dev/null 2>&1; then
  ABS_SRC="$(realpath "$FOLDER_PATH")"
else
  ABS_SRC="$(readlink -f "$FOLDER_PATH")"
fi
[[ -d "$ABS_SRC" ]] || { echo "Error: '$ABS_SRC' is not a directory"; exit 2; }

# Sanitize optional remote subpath (relative to destination bookmark base)
UPLOAD_PATH="${UPLOAD_PATH_RAW#/}"   # drop leading slash if given
UPLOAD_PATH="${UPLOAD_PATH%/}"       # drop trailing slash

# Resolve bookmarks -> "UUID:/base/path/"
SRC_BM_STR="$(globus bookmark show "$SRC_BM")"
DST_BM_STR="$(globus bookmark show "$DST_BM")"

SRC_UUID="${SRC_BM_STR%%:*}"
SRC_BASE="${SRC_BM_STR#*:}"
DST_UUID="${DST_BM_STR%%:*}"
DST_BASE="${DST_BM_STR#*:}"

# Normalize trailing slashes
[[ "${SRC_BASE}" != */ ]] && SRC_BASE="${SRC_BASE}/"
[[ "${DST_BASE}" != */ ]] && DST_BASE="${DST_BASE}/"

# Ensure the source folder lives under the source bookmark base
case "$ABS_SRC/" in
  "${SRC_BASE}"*) : ;;  # ok
  *)
    echo "Error: Source path must be under ${SRC_BASE}"
    echo "       Given: $ABS_SRC"
    exit 3
    ;;
esac

# Compute path RELATIVE to the source bookmark base
REL="${ABS_SRC#${SRC_BASE}}"           # e.g., workspace/AffU/third_party/sonata
REL="${REL%/}"                         # strip trailing slash if any

BASENAME="$(basename "$ABS_SRC")"
# Build Globus endpoint:path strings
# Source: copy *contents* of the folder (trailing slash matters for recursive)
SRC_DIR="${SRC_UUID}:${SRC_BASE}${REL}/"

# Destination: (optional remote subpath)/basename
if [[ -n "$UPLOAD_PATH" ]]; then
  DEST_SUB="${UPLOAD_PATH}/${BASENAME}"
else
  DEST_SUB="${BASENAME}"
fi
DST_DIR="${DST_UUID}:${DST_BASE}${DEST_SUB}/"


echo "== Plan =="
echo "Local absolute source  : $ABS_SRC"
echo "Source bookmark base   : ${SRC_UUID}:${SRC_BASE}"
echo "Relative path          : $REL"
echo "Will transfer (source) : $SRC_DIR"
echo "To (destination)       : $DST_DIR"
[[ -n "$UPLOAD_PATH" ]] && echo "Remote subpath         : ${UPLOAD_PATH}"
echo

if [[ $DRY_RUN -eq 1 ]]; then
  echo "[DRY-RUN] Skipping mkdir and transfer."
  exit 0
fi

# Create destination path recursively (mkdir -p behavior for Globus)
mkdir_p() {
  local prefix="$1"  # e.g., "UUID:/coe-jungaocv/"
  local path="$2"    # e.g., "wzn/workspace/AffU/third_party/sonata"
  IFS='/' read -ra parts <<< "$path"
  local cur="$prefix"
  for part in "${parts[@]}"; do
    [[ -z "$part" ]] && continue
    cur="${cur}${part}/"
    if globus ls "$cur" >/dev/null 2>&1; then
      :  # exists; nothing to do
    else
      globus mkdir "$cur"
    fi
  done
}
mkdir_p "${DST_UUID}:${DST_BASE}" "${DEST_SUB}"

echo "Starting recursive transfer..."
OUT="$(
  globus transfer --recursive \
    --label "upload ${DEST_SUB} $(date +%F)" \
    "$SRC_DIR" "$DST_DIR"
)"
echo "$OUT"

TASK_ID="$(printf '%s\n' "$OUT" | awk -F': ' '/Task ID:/ {print $2}')"
if [[ -n "$TASK_ID" ]]; then
  echo "Waiting for task $TASK_ID to complete..."
  globus task wait "$TASK_ID"
  echo "Task status:"
  globus task show "$TASK_ID" --jmespath 'status'
else
  echo "Warning: Could not detect Task ID from output."
fi
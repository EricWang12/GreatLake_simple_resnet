#!/usr/bin/env bash
set -euo pipefail

# --------- CONFIG (yours) ----------
EP="ab65757f-00f5-4e5b-aa21-133187732a01"
REMOTE_ROOT="/coe-jungaocv/wzn/ego4d/v2/"
LOCAL_ROOT="/nfs/turbo/coe-jungaocv-turbo2/wzn/datasets/AffU_datasets/ego4d/v2/"
DEPTH_LIMIT=100000
# -----------------------------------

ts="$(date +%Y%m%d_%H%M%S)"
OUTDIR="globus_size_check_${ts}"
mkdir -p "$OUTDIR"

REMOTE_RAW="$OUTDIR/remote_raw.tsv"
REMOTE_TSV="$OUTDIR/remote.tsv"
LOCAL_TSV="$OUTDIR/local.tsv"
REMOTE_SORT="$OUTDIR/remote.sorted.tsv"
LOCAL_SORT="$OUTDIR/local.sorted.tsv"
JOINED="$OUTDIR/joined.tsv"

MISSING_LOCAL="$OUTDIR/missing_local.tsv"
MISSING_REMOTE="$OUTDIR/missing_remote.tsv"
MISMATCH="$OUTDIR/size_mismatch.tsv"
SUMMARY="$OUTDIR/summary.txt"

need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: missing command: $1" >&2; exit 1; }; }
need globus
need sort
need join
need awk
need find

# Normalize REMOTE_ROOT to have exactly one trailing slash
REMOTE_BASE="${REMOTE_ROOT%/}/"

echo "[1/5] Remote listing via Globus (this can take a while)..."
# We ask for [path,name,size] to be robust. If 'path' is missing, it will be blank.
# Recursive listing + depth limit documented in globus ls reference. :contentReference[oaicite:1]{index=1}
globus ls -r --recursive-depth-limit "$DEPTH_LIMIT" --format json "${EP}:${REMOTE_BASE}" \
  --jmespath "DATA[?type=='file'].[path,name,size]" \
  --format unix > "$REMOTE_RAW"

echo "[2/5] Normalize remote paths (make them relative to REMOTE_ROOT)..."
awk -F'\t' -v base="$REMOTE_BASE" '
BEGIN {
  sub(/\/+$/, "", base); base = base "/";
}
{
  # Handle 2-col output (if path field not present): name size
  if (NF == 2) { rpath=""; name=$1; size=$2; }
  else { rpath=$1; name=$2; size=$3; }

  # Globus CLI prints null JSON as "None" in unix formatting
  if (rpath == "None" || rpath == "null" || rpath == "NULL") rpath = "";
  if (rpath == "." ) rpath = "";

  # Build a full path guess
  full = name
  if (rpath != "") {
    gsub(/\/+$/, "", rpath)
    full = rpath "/" name
  }

  # Strip base prefix if present
  if (index(full, base) == 1) {
    full = substr(full, length(base) + 1)
  }

  # Remove any leading slashes
  gsub(/^\/+/, "", full)

  # Guard: require size numeric
  if (size ~ /^[0-9]+$/) {
    print full "\t" size
  }
}
' "$REMOTE_RAW" > "$REMOTE_TSV"


echo "[3/5] Local listing (relative paths + byte sizes)..."
if [[ ! -d "$LOCAL_ROOT" ]]; then
  echo "ERROR: LOCAL_ROOT does not exist: $LOCAL_ROOT" >&2
  exit 1
fi

(
  cd "$LOCAL_ROOT"
  # %P = path relative to start dir; %s = file size in bytes
  find . -type f -printf '%P\t%s\n' | sed 's#^\./##'
) > "$LOCAL_TSV"

echo "[4/5] Sort + join..."
sort -t $'\t' -k1,1 "$REMOTE_TSV" > "$REMOTE_SORT"
sort -t $'\t' -k1,1 "$LOCAL_TSV"  > "$LOCAL_SORT"

# joined columns: relpath \t remote_size|MISSING \t local_size|MISSING
join -t $'\t' -a 1 -a 2 -e MISSING -o '0,1.2,2.2' "$REMOTE_SORT" "$LOCAL_SORT" > "$JOINED"

echo "[5/5] Split results..."
: > "$MISSING_LOCAL"
: > "$MISSING_REMOTE"
: > "$MISMATCH"

awk -F'\t' -v out_ml="$MISSING_LOCAL" -v out_mr="$MISSING_REMOTE" -v out_mm="$MISMATCH" '
function abs(x){ return x<0?-x:x }
{
  path=$1; r=$2; l=$3
  if (r=="MISSING") {
    print path "\t" l >> out_mr
  } else if (l=="MISSING") {
    print path "\t" r >> out_ml
  } else if (r != l) {
    d = abs(r - l)
    print path "\t" r "\t" l "\t" d >> out_mm
  }
}
' "$JOINED"

# Summary
ml_cnt=$(wc -l < "$MISSING_LOCAL" | tr -d ' ')
mr_cnt=$(wc -l < "$MISSING_REMOTE" | tr -d ' ')
mm_cnt=$(wc -l < "$MISMATCH" | tr -d ' ')

{
  echo "REMOTE: ${EP}:${REMOTE_BASE}"
  echo "LOCAL : ${LOCAL_ROOT}"
  echo ""
  echo "missing_local_count   = ${ml_cnt}"
  echo "missing_remote_count  = ${mr_cnt}"
  echo "size_mismatch_count   = ${mm_cnt}"
  echo ""
  echo "Outputs:"
  echo "  $MISSING_LOCAL   (path<TAB>remote_bytes)"
  echo "  $MISSING_REMOTE  (path<TAB>local_bytes)"
  echo "  $MISMATCH        (path<TAB>remote_bytes<TAB>local_bytes<TAB>abs_diff_bytes)"
} | tee "$SUMMARY"

echo ""
echo "Done. See: $OUTDIR/"

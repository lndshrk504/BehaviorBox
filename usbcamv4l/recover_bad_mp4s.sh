#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Recover corrupted MP4 files while skipping healthy/playable files.

Usage:
  ./recover_bad_mp4s.sh [options]

Options:
  -i, --input DIR          Input directory to scan (default: ~/Desktop/USB-Recordings)
  -o, --output DIR         Output directory for recovered files
                           (default: <input>/recovery_YYYYmmdd_HHMMSS)
      --check-seconds N    Decode-check duration in seconds for playability test
                           (default: 15, use 0 for ffprobe-only check)
      --remux-only         Try remux recovery only (no re-encode)
      --reencode-only      Try re-encode recovery only (skip remux)
      --preset NAME        x264 preset for re-encode (default: veryfast)
      --crf N              x264 CRF for re-encode (default: 20)
      --dry-run            Print planned actions without running ffmpeg
  -h, --help               Show this help

Examples:
  ./recover_bad_mp4s.sh
  ./recover_bad_mp4s.sh -i ~/Desktop/USB-Recordings --check-seconds 30
  ./recover_bad_mp4s.sh -i /data/cams -o /data/recovered --remux-only
EOF
}

INPUT_DIR="${HOME}/Desktop/USB-Recordings"
OUTPUT_DIR=""
CHECK_SECONDS=15
DO_REMUX=1
DO_REENCODE=1
PRESET="veryfast"
CRF=20
DRY_RUN=0

while (($# > 0)); do
  case "$1" in
    -i|--input)
      INPUT_DIR="${2:-}"; shift 2 ;;
    -o|--output)
      OUTPUT_DIR="${2:-}"; shift 2 ;;
    --check-seconds)
      CHECK_SECONDS="${2:-}"; shift 2 ;;
    --remux-only)
      DO_REMUX=1; DO_REENCODE=0; shift ;;
    --reencode-only)
      DO_REMUX=0; DO_REENCODE=1; shift ;;
    --preset)
      PRESET="${2:-}"; shift 2 ;;
    --crf)
      CRF="${2:-}"; shift 2 ;;
    --dry-run)
      DRY_RUN=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1 ;;
  esac
done

if [[ -z "${INPUT_DIR}" ]]; then
  echo "Input directory is required." >&2
  exit 1
fi
if [[ ! -d "${INPUT_DIR}" ]]; then
  echo "Input directory not found: ${INPUT_DIR}" >&2
  exit 1
fi
if ! [[ "${CHECK_SECONDS}" =~ ^[0-9]+$ ]]; then
  echo "--check-seconds must be a non-negative integer." >&2
  exit 1
fi
if ! [[ "${CRF}" =~ ^[0-9]+$ ]]; then
  echo "--crf must be an integer." >&2
  exit 1
fi
if (( DO_REMUX == 0 && DO_REENCODE == 0 )); then
  echo "Nothing to do: both remux and re-encode are disabled." >&2
  exit 1
fi

for tool in ffprobe ffmpeg find; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "Missing required tool: ${tool}" >&2
    exit 1
  fi
done

if [[ -z "${OUTPUT_DIR}" ]]; then
  OUTPUT_DIR="${INPUT_DIR}/recovery_$(date +%Y%m%d_%H%M%S)"
fi
mkdir -p "${OUTPUT_DIR}/remux" "${OUTPUT_DIR}/reencode"

LOG_FILE="${OUTPUT_DIR}/recovery.log"
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "Input: ${INPUT_DIR}"
echo "Output: ${OUTPUT_DIR}"
echo "Check seconds: ${CHECK_SECONDS}"
echo "Remux enabled: ${DO_REMUX}"
echo "Re-encode enabled: ${DO_REENCODE}"
echo "Dry run: ${DRY_RUN}"
echo

is_playable() {
  local file="$1"

  # Container + stream metadata sanity.
  ffprobe -v error \
    -show_entries format=duration \
    -select_streams v:0 \
    -show_entries stream=codec_name \
    -of default=nokey=1:noprint_wrappers=1 \
    "${file}" >/dev/null 2>&1 || return 1

  # Optional decode check catches many files that probe but still fail playback.
  if (( CHECK_SECONDS > 0 )); then
    ffmpeg -hide_banner -loglevel error -xerror \
      -i "${file}" -map 0:v:0 -t "${CHECK_SECONDS}" \
      -f null - -nostdin >/dev/null 2>&1 || return 1
  fi
  return 0
}

run_ffmpeg() {
  if (( DRY_RUN )); then
    echo "[dry-run] ffmpeg $*"
    return 0
  fi
  ffmpeg "$@"
}

INPUT_ABS="$(cd "${INPUT_DIR}" && pwd)"
OUTPUT_ABS="$(cd "${OUTPUT_DIR}" && pwd)"

if [[ "${OUTPUT_ABS}" == "${INPUT_ABS}"* ]]; then
  mapfile -d '' FILES < <(
    find "${INPUT_DIR}" \
      -path "${OUTPUT_DIR}" -prune -o \
      -type f -iname '*.mp4' -print0 | sort -z
  )
else
  mapfile -d '' FILES < <(find "${INPUT_DIR}" -type f -iname '*.mp4' -print0 | sort -z)
fi
TOTAL=${#FILES[@]}

if (( TOTAL == 0 )); then
  echo "No .mp4 files found under ${INPUT_DIR}"
  exit 0
fi

echo "Found ${TOTAL} MP4 files."
echo

healthy=0
corrupt=0
remux_ok=0
reencode_ok=0
failed=0

for file in "${FILES[@]}"; do
  rel="${file#${INPUT_DIR}/}"
  stem="${rel%.*}"
  stem_safe="${stem// /_}"
  remux_out="${OUTPUT_DIR}/remux/${stem_safe}_remux.mp4"
  reenc_out="${OUTPUT_DIR}/reencode/${stem_safe}_reencode.mp4"
  mkdir -p "$(dirname "${remux_out}")" "$(dirname "${reenc_out}")"

  echo "Checking: ${rel}"
  if is_playable "${file}"; then
    echo "  OK: playable (skipped)"
    ((healthy += 1))
    continue
  fi

  echo "  CORRUPT: attempting recovery"
  ((corrupt += 1))
  recovered=0

  if (( DO_REMUX )); then
    echo "  -> remux copy recovery"
    if run_ffmpeg -hide_banner -loglevel warning -y \
      -err_detect ignore_err -fflags +genpts \
      -i "${file}" -map 0 -c copy -movflags +faststart "${remux_out}"; then
      if (( DRY_RUN )) || is_playable "${remux_out}"; then
        echo "     remux success: ${remux_out}"
        ((remux_ok += 1))
        recovered=1
      else
        echo "     remux output still not playable"
      fi
    else
      echo "     remux failed"
    fi
  fi

  if (( recovered == 0 && DO_REENCODE == 1 )); then
    echo "  -> re-encode recovery (slower)"
    if run_ffmpeg -hide_banner -loglevel warning -y \
      -err_detect ignore_err -fflags +genpts \
      -i "${file}" -map 0:v:0 \
      -c:v libx264 -preset "${PRESET}" -crf "${CRF}" \
      -pix_fmt yuv420p -movflags +faststart "${reenc_out}"; then
      if (( DRY_RUN )) || is_playable "${reenc_out}"; then
        echo "     re-encode success: ${reenc_out}"
        ((reencode_ok += 1))
        recovered=1
      else
        echo "     re-encode output still not playable"
      fi
    else
      echo "     re-encode failed"
    fi
  fi

  if (( recovered == 0 )); then
    echo "  !! could not recover: ${rel}"
    ((failed += 1))
  fi
done

echo
echo "Summary"
echo "  Total files:        ${TOTAL}"
echo "  Healthy skipped:    ${healthy}"
echo "  Corrupt processed:  ${corrupt}"
echo "  Recovered by remux: ${remux_ok}"
echo "  Recovered by reenc: ${reencode_ok}"
echo "  Unrecovered:        ${failed}"
echo "  Log file:           ${LOG_FILE}"

#!/usr/bin/env bash
# Probe harness quota availability for dispatch fallback decisions.
# Usage: fm-harness-quota.sh agy
#   Exit 0: harness appears available for headless use.
#   Exit 1: quota exhausted; prints AGY_QUOTA_EXHAUSTED on stdout.
#   Exit 2: harness missing or probe inconclusive.
set -u

usage() {
  echo "usage: fm-harness-quota.sh agy" >&2
}

agy_quota_exhausted_in_output() {
  local combined=$1
  case "$combined" in
    *Individual\ quota\ reached*|*quota\ reached*) return 0 ;;
  esac
  return 1
}

probe_agy() {
  local agy_bin=${FM_AGY_QUOTA_BIN:-agy}
  local timeout_secs=${FM_AGY_QUOTA_TIMEOUT:-15}
  local out err combined probe_rc

  command -v "$agy_bin" >/dev/null 2>&1 || return 2

  out=$(mktemp "${TMPDIR:-/tmp}/fm-agy-quota.out.XXXXXX")
  err=$(mktemp "${TMPDIR:-/tmp}/fm-agy-quota.err.XXXXXX")

  set +e
  if command -v timeout >/dev/null 2>&1; then
    timeout --signal=TERM "$timeout_secs" \
      "$agy_bin" --dangerously-skip-permissions -p ok >"$out" 2>"$err"
    probe_rc=$?
  else
    "$agy_bin" --dangerously-skip-permissions -p ok >"$out" 2>"$err"
    probe_rc=$?
  fi
  set -u

  combined=$(cat "$out" "$err" 2>/dev/null | tr '\n' ' ')
  rm -f "$out" "$err"

  if agy_quota_exhausted_in_output "$combined"; then
    return 1
  fi

  case "$probe_rc" in
    0) return 0 ;;
    124) return 2 ;;
    *)
      if agy_quota_exhausted_in_output "$combined"; then
        return 1
      fi
      return 2
      ;;
  esac
}

harness=${1:-}
case "$harness" in
  agy)
    set +e
    probe_agy
    rc=$?
    set -u
    if [ "$rc" -eq 1 ]; then
      printf '%s\n' 'AGY_QUOTA_EXHAUSTED'
    fi
    exit "$rc"
    ;;
  '')
    usage
    exit 2
    ;;
  *)
    echo "error: unsupported harness '$harness' (only agy is supported)" >&2
    exit 2
    ;;
esac
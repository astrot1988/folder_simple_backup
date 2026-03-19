#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

list_backups() {
  local dir="$1"
  local file

  for file in "${dir}"/*.tar.gz; do
    [[ -e "${file}" ]] || continue
    basename "${file}"
  done | sort
}

assert_backups() {
  local dir="$1"
  shift

  local actual expected
  actual="$(list_backups "${dir}")"
  expected="$(printf '%s\n' "$@" | sort)"

  [[ "${actual}" == "${expected}" ]] || {
    echo "Expected backups:"
    printf '%s\n' "$@" | sort
    echo
    echo "Actual backups:"
    printf '%s\n' "${actual}"
    fail "backup set mismatch"
  }
}

make_case_dir() {
  mktemp -d
}

create_backups() {
  local dir="$1"
  shift
  local ts

  for ts in "$@"; do
    : >"${dir}/${ts}.tar.gz"
  done
}

run_retention() {
  local dir="$1"
  shift

  env BACKUP_DIR="${dir}" "$@" bash "${ROOT_DIR}/retention.sh" >/dev/null
}

test_keeps_all_when_retention_disabled() {
  local dir
  dir="$(make_case_dir)"
  trap 'rm -rf "${dir}"' RETURN

  create_backups "${dir}" \
    "2024-01-01T10-00-00" \
    "2024-01-02T10-00-00"

  run_retention "${dir}"

  assert_backups "${dir}" \
    "2024-01-01T10-00-00.tar.gz" \
    "2024-01-02T10-00-00.tar.gz"
}

test_keeps_latest_backups_for_last_hours() {
  local dir
  dir="$(make_case_dir)"
  trap 'rm -rf "${dir}"' RETURN

  create_backups "${dir}" \
    "2024-01-01T10-00-00" \
    "2024-01-01T10-30-00" \
    "2024-01-01T11-00-00" \
    "2024-01-01T12-00-00"

  run_retention "${dir}" KEEP_HOURLY=2

  assert_backups "${dir}" \
    "2024-01-01T10-00-00.tar.gz" \
    "2024-01-01T10-30-00.tar.gz" \
    "2024-01-01T11-00-00.tar.gz" \
    "2024-01-01T12-00-00.tar.gz"
}

test_keeps_latest_backups_for_last_days() {
  local dir
  dir="$(make_case_dir)"
  trap 'rm -rf "${dir}"' RETURN

  create_backups "${dir}" \
    "2024-01-01T23-00-00" \
    "2024-01-02T08-00-00" \
    "2024-01-02T21-00-00" \
    "2024-01-03T09-00-00"

  run_retention "${dir}" KEEP_DAILY=2

  assert_backups "${dir}" \
    "2024-01-01T23-00-00.tar.gz" \
    "2024-01-02T08-00-00.tar.gz" \
    "2024-01-02T21-00-00.tar.gz" \
    "2024-01-03T09-00-00.tar.gz"
}

test_keeps_latest_backups_for_last_weeks() {
  local dir
  dir="$(make_case_dir)"
  trap 'rm -rf "${dir}"' RETURN

  create_backups "${dir}" \
    "2024-01-01T08-00-00" \
    "2024-01-02T09-00-00" \
    "2024-01-08T10-00-00" \
    "2024-01-15T11-00-00"

  run_retention "${dir}" KEEP_WEEKLY=2

  assert_backups "${dir}" \
    "2024-01-02T09-00-00.tar.gz" \
    "2024-01-08T10-00-00.tar.gz" \
    "2024-01-15T11-00-00.tar.gz"
}

test_keeps_latest_backups_for_last_months() {
  local dir
  dir="$(make_case_dir)"
  trap 'rm -rf "${dir}"' RETURN

  create_backups "${dir}" \
    "2024-01-05T08-00-00" \
    "2024-02-01T08-00-00" \
    "2024-02-20T08-00-00" \
    "2024-03-01T08-00-00"

  run_retention "${dir}" KEEP_MONTHLY=2

  assert_backups "${dir}" \
    "2024-01-05T08-00-00.tar.gz" \
    "2024-02-01T08-00-00.tar.gz" \
    "2024-02-20T08-00-00.tar.gz" \
    "2024-03-01T08-00-00.tar.gz"
}

test_keeps_latest_backups_for_last_years() {
  local dir
  dir="$(make_case_dir)"
  trap 'rm -rf "${dir}"' RETURN

  create_backups "${dir}" \
    "2023-06-01T08-00-00" \
    "2024-01-01T08-00-00" \
    "2024-12-01T08-00-00" \
    "2025-01-01T08-00-00"

  run_retention "${dir}" KEEP_YEARLY=2

  assert_backups "${dir}" \
    "2023-06-01T08-00-00.tar.gz" \
    "2024-01-01T08-00-00.tar.gz" \
    "2024-12-01T08-00-00.tar.gz" \
    "2025-01-01T08-00-00.tar.gz"
}

test_combines_multiple_retention_policies() {
  local dir
  dir="$(make_case_dir)"
  trap 'rm -rf "${dir}"' RETURN

  create_backups "${dir}" \
    "2024-01-01T23-00-00" \
    "2024-01-02T08-00-00" \
    "2024-01-02T21-00-00" \
    "2024-01-03T09-00-00"

  run_retention "${dir}" KEEP_HOURLY=1 KEEP_DAILY=2

  assert_backups "${dir}" \
    "2024-01-01T23-00-00.tar.gz" \
    "2024-01-02T21-00-00.tar.gz" \
    "2024-01-03T09-00-00.tar.gz"
}

test_keeps_recent_window_and_compacts_older_range() {
  local dir
  dir="$(make_case_dir)"
  trap 'rm -rf "${dir}"' RETURN

  create_backups "${dir}" \
    "2024-01-01T08-00-00" \
    "2024-01-01T09-00-00" \
    "2024-01-02T07-00-00" \
    "2024-01-02T12-00-00" \
    "2024-01-03T07-00-00" \
    "2024-01-03T08-00-00" \
    "2024-01-03T09-00-00"

  run_retention "${dir}" KEEP_HOURLY=2 KEEP_DAILY=3

  assert_backups "${dir}" \
    "2024-01-01T09-00-00.tar.gz" \
    "2024-01-02T12-00-00.tar.gz" \
    "2024-01-03T07-00-00.tar.gz" \
    "2024-01-03T08-00-00.tar.gz" \
    "2024-01-03T09-00-00.tar.gz"
}

test_keeps_all_when_retention_disabled
test_keeps_latest_backups_for_last_hours
test_keeps_latest_backups_for_last_days
test_keeps_latest_backups_for_last_weeks
test_keeps_latest_backups_for_last_months
test_keeps_latest_backups_for_last_years
test_combines_multiple_retention_policies
test_keeps_recent_window_and_compacts_older_range

echo "retention tests passed"

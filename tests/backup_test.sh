#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file_exists() {
  local path="$1"
  [[ -f "${path}" ]] || fail "expected file to exist: ${path}"
}

assert_equals() {
  local actual="$1"
  local expected="$2"
  [[ "${actual}" == "${expected}" ]] || fail "expected '${expected}', got '${actual}'"
}

test_creates_archive_with_source_directory_contents() {
  local tmp_dir source_dir backups_dir archive extracted_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' RETURN

  source_dir="${tmp_dir}/source"
  backups_dir="${tmp_dir}/backups"
  extracted_dir="${tmp_dir}/extracted"

  mkdir -p "${source_dir}/nested" "${backups_dir}" "${extracted_dir}"
  printf 'hello\n' >"${source_dir}/root.txt"
  printf 'nested-value\n' >"${source_dir}/nested/value.txt"

  BACKUP_DIR="${backups_dir}" SOURCE_DIR="${source_dir}" bash "${ROOT_DIR}/backup.sh" >/dev/null

  archive="$(find "${backups_dir}" -maxdepth 1 -type f -name '*.tar.gz' | sort | tail -n 1)"
  [[ -n "${archive}" ]] || fail "expected archive to be created"
  assert_file_exists "${archive}"

  tar -xzf "${archive}" -C "${extracted_dir}"

  assert_file_exists "${extracted_dir}/source/root.txt"
  assert_file_exists "${extracted_dir}/source/nested/value.txt"
  assert_equals "$(cat "${extracted_dir}/source/root.txt")" "hello"
  assert_equals "$(cat "${extracted_dir}/source/nested/value.txt")" "nested-value"
}

test_fails_when_source_directory_is_missing() {
  local tmp_dir backups_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' RETURN

  backups_dir="${tmp_dir}/backups"
  mkdir -p "${backups_dir}"

  if BACKUP_DIR="${backups_dir}" SOURCE_DIR="${tmp_dir}/missing" bash "${ROOT_DIR}/backup.sh" >/dev/null 2>&1; then
    fail "backup.sh should fail for a missing source directory"
  fi
}

test_creates_archive_with_source_directory_contents
test_fails_when_source_directory_is_missing

echo "backup tests passed"

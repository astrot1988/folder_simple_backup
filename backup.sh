#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

: "${BACKUP_DIR:=/backups}"
: "${TAR_EXTRA_OPTS:=}"
: "${SOURCE_DIR:?SOURCE_DIR is required}"

timestamp="$(date '+%Y-%m-%dT%H-%M-%S')"
outfile="${BACKUP_DIR}/${timestamp}.tar.gz"
tmpfile="${outfile}.tmp"

mkdir -p "${BACKUP_DIR}"

if [[ ! -d "${SOURCE_DIR}" ]]; then
  echo "SOURCE_DIR does not exist or is not a directory: ${SOURCE_DIR}" >&2
  exit 1
fi

source_parent="$(dirname "${SOURCE_DIR}")"
source_name="$(basename "${SOURCE_DIR}")"

# TAR_EXTRA_OPTS is intentionally word-split to allow passing standard tar flags.
# shellcheck disable=SC2086
tar ${TAR_EXTRA_OPTS} -C "${source_parent}" -czf "${tmpfile}" "${source_name}"

mv "${tmpfile}" "${outfile}"
echo "Backup created: ${outfile}"

bash "${SCRIPT_DIR}/retention.sh"

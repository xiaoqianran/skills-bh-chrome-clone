#!/usr/bin/env bash
# Run all offline tests (no live MAIN browser required).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "######## cookie_filter + cookie_io ########"
python3 "${DIR}/test_cookie_filter.py"

echo
echo "######## HARD_RULES guards ########"
bash "${DIR}/test_guards.sh"

echo
echo "######## CLI smoke ########"
bash "${DIR}/smoke_cli.sh"

echo
echo "ALL_TESTS_OK"

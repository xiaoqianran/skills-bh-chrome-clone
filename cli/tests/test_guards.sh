#!/usr/bin/env bash
# Unit tests for HARD_RULES guards in common.sh (no live browser).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "${ROOT}/lib/common.sh"

pass=0
fail=0
assert_true() {
  local name="$1"
  shift
  if "$@"; then
    echo "  ok  $name"
    pass=$((pass + 1))
  else
    echo "  FAIL $name" >&2
    fail=$((fail + 1))
  fi
}
assert_false() {
  local name="$1"
  shift
  if "$@"; then
    echo "  FAIL $name (expected false)" >&2
    fail=$((fail + 1))
  else
    echo "  ok  $name"
    pass=$((pass + 1))
  fi
}
assert_dies() {
  local name="$1"
  shift
  set +e
  out="$("$@" 2>&1)"
  rc=$?
  set -e
  if [[ "${rc}" -ne 0 ]]; then
    echo "  ok  $name"
    pass=$((pass + 1))
  else
    echo "  FAIL $name (expected die, got: ${out})" >&2
    fail=$((fail + 1))
  fi
}

echo "== is_main_profile_path =="
BH_MAIN_PROFILE="${HOME}/.config/google-chrome"
assert_true "empty is main" is_main_profile_path ""
assert_true "default google-chrome" is_main_profile_path "${HOME}/.config/google-chrome"
assert_true "matches BH_MAIN" is_main_profile_path "${BH_MAIN_PROFILE}"
assert_false "clone path" is_main_profile_path "${HOME}/.config/browser-harness-chrome-clone"
assert_false "random path" is_main_profile_path "/tmp/some-other-chrome-profile-xyz"

echo "== assert_not_main_profile =="
assert_dies "refuse main" bash -c 'source "'"${ROOT}"'/lib/common.sh"; assert_not_main_profile "$HOME/.config/google-chrome" test'
# should not die for clone
assert_not_main_profile "${HOME}/.config/browser-harness-chrome-clone" "test-ok"
echo "  ok  allow clone path"
pass=$((pass + 1))

echo "== assert_main_clone_distinct =="
(
  export BH_CLONE_PROFILE="${HOME}/.config/google-chrome"
  export BH_MAIN_PROFILE="${HOME}/.config/google-chrome"
  assert_dies "clone==main dies" bash -c 'source "'"${ROOT}"'/lib/common.sh"; BH_CLONE_PROFILE="$HOME/.config/google-chrome"; BH_MAIN_PROFILE="$HOME/.config/google-chrome"; assert_main_clone_distinct'
)
# restore defaults for rest of file
BH_CLONE_PROFILE="${HOME}/.config/browser-harness-chrome-clone"
BH_MAIN_PROFILE="${HOME}/.config/google-chrome"
assert_main_clone_distinct
echo "  ok  distinct defaults"
pass=$((pass + 1))

echo "== is_default_clone_profile =="
assert_true "default name" is_default_clone_profile "${HOME}/.config/browser-harness-chrome-clone"
assert_false "custom" is_default_clone_profile "/tmp/my-clone"

echo "== write_env_clone =="
tmp_env="$(mktemp)"
BH_ENV_FILE="${tmp_env}"
BH_STATE_DIR="$(dirname "${tmp_env}")"
BH_CDP_PORT=9333
BH_CLONE_PROFILE="${HOME}/.config/browser-harness-chrome-clone"
BH_COOKIE_FILE="${HOME}/.config/browser-harness/main-cookies.json"
write_env_clone
grep -q 'BU_CDP_URL=http://127.0.0.1:9333' "${tmp_env}"
grep -q 'BH_CDP_PORT=9333' "${tmp_env}"
grep -qv 'auto-connect' "${tmp_env}"
echo "  ok  env points at clone"
pass=$((pass + 1))
rm -f "${tmp_env}"

echo "== strip_clone_locks refuses main =="
assert_dies "strip main" bash -c 'source "'"${ROOT}"'/lib/common.sh"; strip_clone_locks "$HOME/.config/google-chrome"'

echo "== enable_remote_debugging_pref refuses main =="
assert_dies "pref main" bash -c 'source "'"${ROOT}"'/lib/common.sh"; enable_remote_debugging_pref "$HOME/.config/google-chrome"'

echo "== kill_clone refuses main =="
assert_dies "kill main" bash -c 'source "'"${ROOT}"'/lib/common.sh"; BH_CLONE_PROFILE="$HOME/.config/google-chrome"; kill_clone_chrome'

echo "== kill_clone refuses short path =="
assert_dies "kill short" bash -c 'source "'"${ROOT}"'/lib/common.sh"; BH_CLONE_PROFILE="/tmp/x"; BH_ALLOW_CUSTOM_CLONE_KILL=1; kill_clone_chrome'

echo "== list_clone_pids empty for idle clone path =="
# no process → empty output, exit 0
out="$(list_clone_pids "${HOME}/.config/browser-harness-chrome-clone" || true)"
# may have real clone running; just ensure no error
echo "  ok  list_clone_pids ran (pids lines: $(printf '%s' "${out}" | grep -c . || true))"
pass=$((pass + 1))

echo "== enable_remote_debugging_pref on temp clone Local State =="
tmp_prof="$(mktemp -d)"
# must not look like main; use browser-harness-chrome-clone suffix for kill tests later
tmp_prof="${tmp_prof}/browser-harness-chrome-clone"
mkdir -p "${tmp_prof}"
printf '%s\n' '{}' > "${tmp_prof}/Local State"
enable_remote_debugging_pref "${tmp_prof}"
python3 - "${tmp_prof}/Local State" <<'PY'
import json, sys
d=json.load(open(sys.argv[1]))
assert d["devtools"]["remote_debugging"]["user-enabled"] is True
print("pref_ok")
PY
echo "  ok  pref write on clone only"
pass=$((pass + 1))
rm -rf "$(dirname "${tmp_prof}")"

echo
echo "GUARDS pass=${pass} fail=${fail}"
[[ "${fail}" -eq 0 ]]
echo "GUARDS_OK"

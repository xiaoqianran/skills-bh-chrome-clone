#!/usr/bin/env bash
# Multi-clone pool: restore browser-harness multi-open without sharing one Chrome.
#
# Local harness truth: one Chrome process = one focus. Parallel tasks need
# either cloud browsers (start_remote_daemon) OR multiple local clones.
#
# HARD_RULES: never touch MAIN Chrome.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

usage() {
  cat <<'USAGE'
Usage:
  bh-clone pool start <N>     Start N worker clones (w1..wN), ports from 9333
  bh-clone pool list          List registered instances + CDP status
  bh-clone pool stop [name]   Stop one instance (or all workers if omitted)
  bh-clone pool env           Print how to run parallel harness jobs
  bh-clone pool sync          Export MAIN cookies once, inject into all instances

Examples (true multi-open):
  bh-clone pool start 2
  bh-clone pool sync          # optional: same cookies on all workers

  # shell A — zhihu
  source ~/.config/browser-harness/env.w1
  browser-harness <<'PY'
  new_tab("https://www.zhihu.com/")
  print(page_info())
  PY

  # shell B — other site (parallel)
  source ~/.config/browser-harness/env.w2
  browser-harness <<'PY'
  new_tab("https://duckduckgo.com/")
  print(page_info())
  PY

Each worker: unique user-data-dir + CDP port + BU_NAME (harness daemon name).
USAGE
}

cmd="${1:-}"
shift || true

case "${cmd}" in
  ""|-h|--help|help)
    usage
    exit 0
    ;;
  start)
    n="${1:-}"
    [[ -n "${n}" && "${n}" =~ ^[1-9][0-9]*$ ]] || die "usage: bh-clone pool start <N>  (N>=1)"
    [[ "${n}" -le 20 ]] || die "refuse pool size > 20"
    require_browser_harness
    info "pool start: ${n} local clone(s) (MAIN untouched)"
    # Stop legacy single-clone profile if it still holds a port (pre-multi-instance)
    (
      BH_INSTANCE=default
      unset BH_CDP_PORT_EXPLICIT || true
      BH_CLONE_PROFILE="${HOME}/.config/browser-harness-chrome-clone"
      BH_CDP_PORT="${BH_PORT_BASE}"
      kill_clone_chrome 2>/dev/null || true
    )
    for i in $(seq 1 "${n}"); do
      name="w${i}"
      prefer=$((BH_PORT_BASE + i - 1))
      BH_INSTANCE="${name}"
      unset BH_CDP_PORT_EXPLICIT || true
      reg="$(instance_registry_port "${name}" || true)"
      if [[ -n "${reg}" ]] && { ! cdp_ready "${reg}" || true; }; then
        # reuse registry port if free; if busy, reallocate below
        if ! cdp_ready "${reg}"; then
          BH_CDP_PORT_EXPLICIT="${reg}"
        fi
      fi
      if [[ -z "${BH_CDP_PORT_EXPLICIT:-}" ]]; then
        if ! cdp_ready "${prefer}"; then
          BH_CDP_PORT_EXPLICIT="${prefer}"
        else
          BH_CDP_PORT_EXPLICIT="$(instance_next_port)"
        fi
      fi
      apply_instance_config
      info "  [${name}] profile=${BH_CLONE_PROFILE} port=${BH_CDP_PORT} BU_NAME=${BH_BU_NAME}"
      # ensure may reallocate if port is up but not our profile
      if ! bash "${BH_CLONE_ROOT}/scripts/ensure.sh" --instance "${name}" --port "${BH_CDP_PORT}"; then
        warn "ensure failed on :${BH_CDP_PORT}, retry with free port"
        BH_INSTANCE="${name}"
        BH_CDP_PORT_EXPLICIT="$(instance_next_port)"
        apply_instance_config
        bash "${BH_CLONE_ROOT}/scripts/ensure.sh" --instance "${name}" --port "${BH_CDP_PORT}"
      fi
      # re-read after ensure (port may have changed only if we retry)
      BH_INSTANCE="${name}"
      if [[ -f "${BH_STATE_DIR}/env.${name}" ]]; then
        # shellcheck disable=SC1090
        source "${BH_STATE_DIR}/env.${name}"
        BH_CDP_PORT_EXPLICIT="${BH_CDP_PORT}"
      fi
      apply_instance_config
      write_env_clone
    done
    if [[ -f "${BH_STATE_DIR}/env.w1" ]]; then
      cp -f "${BH_STATE_DIR}/env.w1" "${BH_STATE_DIR}/env"
      info "default env → env.w1"
    fi
    echo
    bash "${BH_CLONE_ROOT}/scripts/pool.sh" env
    ;;
  list)
    printf '%-10s %-6s %-8s %s\n' "NAME" "PORT" "CDP" "PROFILE"
    while IFS=$'\t' read -r name port profile buname; do
      [[ -z "${name}" ]] && continue
      st="down"
      if cdp_ready "${port}"; then st="up"; fi
      printf '%-10s %-6s %-8s %s\n' "${name}" "${port}" "${st}" "${profile}"
    done < <(list_registered_instances)
    ;;
  stop)
    target="${1:-}"
    if [[ -z "${target}" ]]; then
      info "pool stop: all registered clones"
      while IFS=$'\t' read -r name port profile buname; do
        [[ -z "${name}" ]] && continue
        BH_INSTANCE="${name}"
        BH_CDP_PORT_EXPLICIT="${port}"
        apply_instance_config
        info "  stop ${name} (:${port})"
        kill_clone_chrome || true
      done < <(list_registered_instances)
    else
      BH_INSTANCE="${target}"
      apply_instance_config
      info "stop instance ${target} (:${BH_CDP_PORT})"
      kill_clone_chrome || true
    fi
    ;;
  env|how)
    cat <<EOF
# Parallel browser-harness (each line is a separate process/shell)

# Worker 1
source ${BH_STATE_DIR}/env.w1   # or: export BU_CDP_URL=... BU_NAME=clone-w1
browser-harness <<'PY'
print(page_info())
PY

# Worker 2
source ${BH_STATE_DIR}/env.w2
browser-harness <<'PY'
print(page_info())
PY

# Important:
# - Same BU_CDP_URL for two processes = SAME browser (tabs fight). Use env.w1 vs env.w2.
# - BU_NAME must differ so each worker has its own harness daemon.
# - chrome-devtools MCP is still one browserUrl (pick one instance, usually w1).
# - Cloud alternative: start_remote_daemon("a"); BU_NAME=a browser-harness ...
EOF
    ;;
  sync)
    info "pool sync: export MAIN once, inject every registered instance"
    # export only (via sync on first instance), then inject others
    first=1
    while IFS=$'\t' read -r name port profile buname; do
      [[ -z "${name}" ]] && continue
      if [[ "${first}" == "1" ]]; then
        bash "${BH_CLONE_ROOT}/scripts/sync.sh" --instance "${name}" --port "${port}"
        first=0
      else
        bash "${BH_CLONE_ROOT}/scripts/sync.sh" --instance "${name}" --port "${port}" --inject-only
      fi
    done < <(list_registered_instances)
    if [[ "${first}" == "1" ]]; then
      die "no instances registered — run: bh-clone pool start N"
    fi
    info "pool sync done"
    ;;
  *)
    usage >&2
    die "unknown pool command: ${cmd}"
    ;;
esac

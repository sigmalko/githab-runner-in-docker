#!/usr/bin/env bash
set -euo pipefail
cd /runner
if [[ ! -f ./run.sh ]]; then
    cp -a /opt/actions-runner/. /runner/
fi
if [[ ! -f .runner ]]; then
    : "${RUNNER_URL:?Set RUNNER_URL to a repository or organization URL.}"
    if [[ -n "${RUNNER_TOKEN_FILE:-}" ]]; then
        RUNNER_TOKEN="$(cat "$RUNNER_TOKEN_FILE")"
    fi
    : "${RUNNER_TOKEN:?Set a fresh registration token via RUNNER_TOKEN or RUNNER_TOKEN_FILE.}"
    args=(--unattended --url "$RUNNER_URL" --token "$RUNNER_TOKEN"
          --name "${RUNNER_NAME:-$(hostname)}" --work "${RUNNER_WORKDIR:-/runner/_work}")
    if [[ -n "${RUNNER_LABELS:-}" ]]; then args+=(--labels "$RUNNER_LABELS"); fi
    if [[ -n "${RUNNER_GROUP:-}" ]]; then args+=(--runnergroup "$RUNNER_GROUP"); fi
    ./config.sh "${args[@]}"
else
    echo 'Using saved runner registration from /runner.'
fi
unset RUNNER_TOKEN RUNNER_TOKEN_FILE
exec ./run.sh

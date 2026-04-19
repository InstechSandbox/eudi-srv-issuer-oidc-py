#!/bin/sh

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$repo_dir"

venv_dir=${VENV_DIR:-$repo_dir/.venv-validate}

select_python() {
	if [ -n "${PYTHON_BIN:-}" ]; then
		printf '%s\n' "$PYTHON_BIN"
		return
	fi

	for candidate in python3.10 python3.9 python3.11 python3; do
		if command -v "$candidate" >/dev/null 2>&1; then
			printf '%s\n' "$candidate"
			return
		fi
	done

	printf 'No suitable Python interpreter found\n' >&2
	exit 1
}

python_bin=$(select_python)

"$python_bin" -m venv "$venv_dir"
. "$venv_dir/bin/activate"

python -m pip install --upgrade pip
python -m pip install -r requirements.txt
python -m compileall application.py request_manager.py server.py views.py yaml_to_json.py
bash -n run.sh patch_auth_server_local.sh

kill_listener_on_port() {
	port="$1"
	pids=$(lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null || true)
	if [ -n "$pids" ]; then
		kill $pids 2>/dev/null || true
	fi
}

export REPO_DIR="$repo_dir"
auth_smoke_port=${AUTH_SMOKE_PORT:-5001}
auth_log_file=${AUTH_LOG_FILE:-/tmp/oidc_log_dev/logs.log}

mkdir -p "$(dirname "$auth_log_file")"

if ! python - <<'PY'
import os
import sys

from idpyoidc.configure import Configuration, create_from_config_file
from idpyoidc.server.configure import OPConfiguration

repo_dir = os.environ["REPO_DIR"]
sys.path.insert(0, repo_dir)

from application import oidc_provider_init_app

config = create_from_config_file(
    Configuration,
    entity_conf=[{"class": OPConfiguration, "attr": "op", "path": ["op", "server_info"]}],
    filename=os.path.join(repo_dir, "config.json"),
    base_path=repo_dir,
)

app = oidc_provider_init_app(config.op, "oidc_op")
response = app.test_client().get("/.well-known/openid-configuration")
if response.status_code != 200:
    raise SystemExit(f"smoke test failed with status {response.status_code}")
PY
then
	kill_listener_on_port "$auth_smoke_port"
	printf 'Auth server smoke test failed\n' >&2
	exit 1
fi

printf 'Validated auth server dependencies and smoke test in %s\n' "$venv_dir"
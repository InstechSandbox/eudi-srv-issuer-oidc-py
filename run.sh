#!/bin/bash

set -euo pipefail

AUTH_CONFIG_FILE="${AUTH_CONFIG_FILE:-config.json}"
AUTH_TLS_CERT_FILE="${AUTH_TLS_CERT_FILE:-}"
AUTH_TLS_KEY_FILE="${AUTH_TLS_KEY_FILE:-}"
AUTH_RUNTIME_DIR="${AUTH_RUNTIME_DIR:-$(pwd -P)/.generated/runtime}"
AUTH_LOG_FILE="${AUTH_LOG_FILE:-/tmp/oidc_log_dev/logs.log}"

should_render_runtime_config=0
if [[ -n "${AUTH_BASE_URL:-}" || -n "${AUTH_AUTHORIZATION_REDIRECT_URL:-}" || "${AUTH_GENERATE_RUNTIME_CONFIG:-0}" == "1" ]]; then
	should_render_runtime_config=1
fi

if [[ "$should_render_runtime_config" == "1" ]]; then
	mapfile -t rendered_paths < <(AUTH_RUNTIME_DIR="$AUTH_RUNTIME_DIR" python3 render_runtime_config.py)
	AUTH_CONFIG_FILE="${rendered_paths[0]}"
	export AUTH_OPENID_CONFIGURATION_FILE="${rendered_paths[1]}"
fi

mkdir -p "$(dirname "$AUTH_LOG_FILE")"

if [[ -z "$AUTH_TLS_CERT_FILE" && -z "$AUTH_TLS_KEY_FILE" && -f server.crt && -f server.key ]]; then
	AUTH_TLS_CERT_FILE="server.crt"
	AUTH_TLS_KEY_FILE="server.key"
fi

args=(python3 server.py "$AUTH_CONFIG_FILE")

if [[ -n "$AUTH_TLS_CERT_FILE" || -n "$AUTH_TLS_KEY_FILE" ]]; then
	if [[ -z "$AUTH_TLS_CERT_FILE" || -z "$AUTH_TLS_KEY_FILE" ]]; then
		echo "Both AUTH_TLS_CERT_FILE and AUTH_TLS_KEY_FILE must be set when enabling TLS" >&2
		exit 1
	fi

	args+=(--cert "$AUTH_TLS_CERT_FILE" --key "$AUTH_TLS_KEY_FILE")
fi

exec "${args[@]}"
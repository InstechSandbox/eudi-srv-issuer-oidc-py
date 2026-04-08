set -euo pipefail

detect_lan_ip() {
    ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true
}

DETECTED_LAN_IP="$(detect_lan_ip)"

MYIP="${MYIP:-${DETECTED_LAN_IP:-localhost}}"
ISSUER_PORT="${ISSUER_PORT:-5002}"
AUTH_PORT="${AUTH_PORT:-5001}"
LOCAL_RUNTIME_DIR="${LOCAL_RUNTIME_DIR:-$(pwd -P)/.local/runtime}"
AUTH_CONFIG_FILE="${AUTH_CONFIG_FILE:-$LOCAL_RUNTIME_DIR/config.json}"
AUTH_OPENID_CONFIGURATION_FILE="${AUTH_OPENID_CONFIGURATION_FILE:-$LOCAL_RUNTIME_DIR/openid-configuration.json}"

ISSUER_BASE="https://${MYIP}:${ISSUER_PORT}"
AUTH_BASE="https://${MYIP}:${AUTH_PORT}"

mkdir -p "$LOCAL_RUNTIME_DIR"
mkdir -p /tmp/oidc_log_dev

python3 - <<PY
import json
from pathlib import Path

source_path = Path("config.json")
output_path = Path("${AUTH_CONFIG_FILE}")
output_path.parent.mkdir(parents=True, exist_ok=True)

cfg = json.loads(source_path.read_text())
trusted_attesters_path = str(Path("trusted_attesters").resolve())

cfg["port"] = ${AUTH_PORT}
cfg["domain"] = "${MYIP}:${AUTH_PORT}"
cfg["base_url"] = "${AUTH_BASE}"
cfg["authorization_redirect_url"] = "${ISSUER_BASE}/auth_choice"

cfg["op"]["server_info"]["add_ons"]["dpop"]["kwargs"]["allowed_htu"] = [
    f"https://${MYIP}:${AUTH_PORT}/token",
    f"https://${MYIP}:${AUTH_PORT}/oidc/token"
]

cfg["op"]["server_info"]["endpoint"]["token"]["kwargs"]["trusted_attesters_path"] = trusted_attesters_path
cfg["op"]["server_info"]["endpoint"]["pushed_authorization"]["kwargs"]["trusted_attesters_path"] = trusted_attesters_path

cfg["op"]["server_info"]["issuer"] = "https://{domain}"
cfg["webserver"]["port"] = ${AUTH_PORT}
cfg["webserver"]["domain"] = "{domain}"

output_path.write_text(json.dumps(cfg, indent=2))
print("generated", output_path)
print("trusted_attesters_path", trusted_attesters_path)
PY

python3 - <<PY
import json
import re
from pathlib import Path

source_path = Path("openid-configuration.json")
output_path = Path("${AUTH_OPENID_CONFIGURATION_FILE}")
output_path.parent.mkdir(parents=True, exist_ok=True)

cfg = json.loads(source_path.read_text())
for key in (
    "issuer",
    "registration_endpoint",
    "introspection_endpoint",
    "authorization_endpoint",
    "token_endpoint",
    "userinfo_endpoint",
    "end_session_endpoint",
    "pushed_authorization_request_endpoint",
    "jwks_uri",
):
    cfg[key] = re.sub(r"^https?://[^/]+", "${AUTH_BASE}", cfg[key])
cfg["token_endpoint_auth_methods_supported"] = [
    "public",
    "attest_jwt_client_auth",
]
cfg["client_attestation_signing_alg_values_supported"] = [
    "ES256",
    "ES384",
    "ES512",
    "RS256",
    "RS384",
    "RS512",
]
cfg["client_attestation_pop_signing_alg_values_supported"] = [
    "ES256",
    "ES384",
    "ES512",
    "RS256",
    "RS384",
    "RS512",
]
output_path.write_text(json.dumps(cfg, indent=4))
print("generated", output_path)
PY

echo
echo "Authorization server local runtime files generated."
echo "Expected runtime:"
echo "  Auth server: ${AUTH_BASE}"
echo "  Redirect to : ${ISSUER_BASE}/auth_choice"
echo "  Config file : ${AUTH_CONFIG_FILE}"
echo "  Discovery   : ${AUTH_OPENID_CONFIGURATION_FILE}"
echo
echo "Start auth server with:"
echo "  AUTH_CONFIG_FILE='${AUTH_CONFIG_FILE}' AUTH_OPENID_CONFIGURATION_FILE='${AUTH_OPENID_CONFIGURATION_FILE}' ./run.sh"

#!/usr/bin/env python3
import json
import os
from pathlib import Path
from urllib.parse import urlparse


def env_or_default(name: str, default: str) -> str:
    value = os.getenv(name)
    return value if value else default


def derive_domain(base_url: str, fallback: str) -> str:
    parsed = urlparse(base_url)
    return parsed.netloc or fallback


def rewrite_openid_metadata(document: dict, base_url: str) -> dict:
    normalized_base = base_url.rstrip("/")
    rewritten = dict(document)

    rewritten["issuer"] = normalized_base
    rewritten["registration_endpoint"] = f"{normalized_base}/registration"
    rewritten["introspection_endpoint"] = f"{normalized_base}/introspection"
    rewritten["authorization_endpoint"] = f"{normalized_base}/authorization"
    rewritten["token_endpoint"] = f"{normalized_base}/token"
    rewritten["userinfo_endpoint"] = f"{normalized_base}/userinfo"
    rewritten["end_session_endpoint"] = f"{normalized_base}/session"
    rewritten["pushed_authorization_request_endpoint"] = f"{normalized_base}/pushed_authorization"
    rewritten["jwks_uri"] = f"{normalized_base}/static/jwks.json"

    return rewritten


def main() -> None:
    repo_dir = Path(__file__).resolve().parent
    runtime_dir = Path(env_or_default("AUTH_RUNTIME_DIR", str(repo_dir / ".generated" / "runtime")))
    config_template_path = Path(env_or_default("AUTH_CONFIG_TEMPLATE_FILE", str(repo_dir / "config.json")))
    openid_template_path = Path(
        env_or_default(
            "AUTH_OPENID_CONFIGURATION_TEMPLATE_FILE",
            str(repo_dir / "openid-configuration.json"),
        )
    )

    config = json.loads(config_template_path.read_text(encoding="utf-8"))
    openid_configuration = json.loads(openid_template_path.read_text(encoding="utf-8"))

    port = int(env_or_default("AUTH_PORT", str(config["webserver"]["port"])))
    base_url = env_or_default("AUTH_BASE_URL", config["base_url"]).rstrip("/")
    domain = env_or_default("AUTH_DOMAIN", derive_domain(base_url, config["domain"]))
    authorization_redirect_url = env_or_default(
        "AUTH_AUTHORIZATION_REDIRECT_URL",
        config["authorization_redirect_url"],
    )
    auth_log_file = env_or_default(
        "AUTH_LOG_FILE",
        config["logging"]["handlers"]["file"]["filename"],
    )
    trusted_attesters_path = env_or_default(
        "AUTH_TRUSTED_ATTESTERS_PATH",
        str((repo_dir / "trusted_attesters").resolve()),
    )
    auth_tls_cert_file = os.getenv("AUTH_TLS_CERT_FILE", "")
    auth_tls_key_file = os.getenv("AUTH_TLS_KEY_FILE", "")

    config["port"] = port
    config["domain"] = domain
    config["server_name"] = "{domain}"
    config["base_url"] = base_url
    config["authorization_redirect_url"] = authorization_redirect_url
    config["logging"]["handlers"]["file"]["filename"] = auth_log_file
    config["op"]["server_info"]["issuer"] = "https://{domain}"
    config["op"]["server_info"]["add_ons"]["dpop"]["kwargs"]["allowed_htu"] = [
        f"{base_url}/token",
        f"{base_url}/oidc/token",
    ]
    config["op"]["server_info"]["endpoint"]["token"]["kwargs"]["trusted_attesters_path"] = trusted_attesters_path
    config["op"]["server_info"]["endpoint"]["pushed_authorization"]["kwargs"]["trusted_attesters_path"] = trusted_attesters_path
    config["webserver"]["port"] = port
    config["webserver"]["domain"] = "{domain}"

    if auth_tls_cert_file and auth_tls_key_file:
        config["webserver"]["server_cert"] = auth_tls_cert_file
        config["webserver"]["server_key"] = auth_tls_key_file
    else:
        config["webserver"].pop("server_cert", None)
        config["webserver"].pop("server_key", None)

    runtime_dir.mkdir(parents=True, exist_ok=True)
    Path(auth_log_file).parent.mkdir(parents=True, exist_ok=True)
    rendered_config_path = runtime_dir / "config.json"
    rendered_openid_path = runtime_dir / "openid-configuration.json"

    rendered_config_path.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
    rendered_openid_path.write_text(
        json.dumps(rewrite_openid_metadata(openid_configuration, base_url), indent=4) + "\n",
        encoding="utf-8",
    )

    print(rendered_config_path)
    print(rendered_openid_path)


if __name__ == "__main__":
    main()
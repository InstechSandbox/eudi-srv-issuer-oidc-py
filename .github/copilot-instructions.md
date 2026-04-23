# Auth Server Repo Guidance

- Use GPT-5.4 by default for protocol-facing work in this repo.
- Treat `project-docs/docs/EIDAS_ARF_Implementation_Brief.md` and `project-docs/docs/AI_Working_Agreement.md` as mandatory constraints.
- This repo owns the authorization and token server behaviour used by the local issuance reference flow.
- Minimize auth-server changes unless verifier or issuance interoperability requires them.
- When discovery metadata, token handling, wallet attestation, or local auth runtime behaviour changes, update `project-docs` in the same task.
- Default Git flow in this workspace is local `wip/<stream>` commits promoted into protected default branches through reviewed pull requests; do not publish remote `wip/<stream>` branches unless explicitly requested.

## Local Checks

- `./validate_local_build.sh`

## Sensitive Areas

- Do not casually modify discovery metadata, PAR handling, token endpoint semantics, or wallet attestation support.
- Keep local-only certificates, keys, and JWKS artifacts out of version control.
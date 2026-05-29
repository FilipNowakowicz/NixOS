User-scoped auth backups for the Home Manager `sops-nix` module live here.

Managed files in this directory:

- `claude-credentials.json`
- `gemini-oauth_creds.json`
- `gh-hosts.yaml`
- `gcloud-application_default_credentials.json`
- `user-identity.yaml`

If any of these files are committed, they must be `sops`-encrypted first. The
matching Home Manager declarations are in `home/users/user/secrets.nix`.
Codex OAuth is intentionally not managed here because its refresh token state is
mutated by the CLI and stale restored snapshots can break app connector startup.

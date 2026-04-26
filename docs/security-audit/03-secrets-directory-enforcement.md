# Secrets Directory Enforcement

## Goal

Make plaintext files under `hosts/*/secrets/*` fail local hooks and CI.

## Scope

- tighten `pre-commit-hooks.nix`
- add a repo check for secrets-directory content rules
- allow only encrypted binaries (`.enc`, `.age`) and SOPS YAML with `sops:` metadata

## Likely Files

- `pre-commit-hooks.nix`
- `flake.nix`
- `scripts/*` or `tests/*` if a dedicated checker script is cleaner
- `.plaintext-secrets-allowlist` only if strictly necessary

## Tasks

- [ ] remove the blanket skip for `hosts/*/secrets/*`
- [ ] define valid file classes inside secrets directories
- [ ] fail on plaintext YAML/text files without SOPS metadata
- [ ] ensure the allowlist cannot silently bypass secrets-directory rules
- [ ] add CI/flake coverage so the check runs outside pre-commit

## Acceptance Criteria

- plaintext files in `hosts/*/secrets/*` are rejected
- valid `.enc` and `.age` files continue to pass
- SOPS YAML with `sops:` metadata continues to pass
- the enforcement path is documented in code or tests

## Validation

- run the new secrets-directory check directly
- `nix build '.#checks.x86_64-linux.pre-commit-check'`
- `nix flake check --no-build`

## Notes

- Keep the implementation simple and repo-local; avoid introducing a large dependency just to parse YAML.

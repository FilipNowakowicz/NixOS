{
  pkgs,
  pre-commit-hooks,
  system,
}:
let
  statixStaged = pkgs.writeShellScript "statix-staged" ''
    set -euo pipefail

    has_failed=0
    for path in "$@"; do
      ${pkgs.statix}/bin/statix check --format errfmt "$path" || has_failed=1
    done

    exit "$has_failed"
  '';

  noPlaintextSecrets = pkgs.writeShellScript "no-plaintext-secrets" ''
    set -euo pipefail

    allowlist_file=".plaintext-secrets-allowlist"
    has_failed=0
    pattern='(ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|xox[baprs]-[A-Za-z0-9-]{10,}|-----BEGIN (OPENSSH|RSA|EC|DSA|PRIVATE KEY)-----|([a-z0-9_-]*(api[_-]?key|auth[_-]?token|access[_-]?token|secret|password|passwd)[a-z0-9_-]*[[:space:]]*[:=][[:space:]]*"?[A-Za-z0-9_+=/-]{16,}"?))'

    is_allowlisted() {
      local path="$1"
      if [[ -f "$allowlist_file" ]]; then
        while IFS= read -r line; do
          [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
          if [[ "$path" == $line ]]; then
            return 0
          fi
        done < "$allowlist_file"
      fi
      return 1
    }

    for path in "$@"; do
      case "$path" in
        hosts/*/secrets/*|*.enc|*.age|.sops.yaml|flake.lock|result|result-*)
          continue
          ;;
      esac

      if is_allowlisted "$path"; then
        continue
      fi

      if ! git cat-file -e ":$path" 2>/dev/null; then
        continue
      fi

      if git show ":$path" | grep -Einq "$pattern"; then
        echo "Potential plaintext secret in staged file: $path" >&2
        echo "Add a justified path to .plaintext-secrets-allowlist if this is intentional." >&2
        has_failed=1
      fi
    done

    exit "$has_failed"
  '';
in
pre-commit-hooks.lib.${system}.run {
  src = ./.;

  hooks = {
    nixfmt-rfc-style.enable = true;
    deadnix.enable = true;

    statix-staged = {
      enable = true;
      name = "statix";
      entry = "${statixStaged}";
      language = "system";
      pass_filenames = true;
      files = "\\.nix$";
    };

    no-plaintext-secrets = {
      enable = true;
      name = "no-plaintext-secrets";
      entry = "${noPlaintextSecrets}";
      language = "system";
      pass_filenames = true;
      types = [ "text" ];
    };
  };
}

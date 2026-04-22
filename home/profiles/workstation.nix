{ pkgs, ... }:
let
  # Skip heavy packages during CI builds to avoid disk exhaustion
  skipHeavyPackages = builtins.getEnv "CI" != "";
in
{
  home.packages =
    with pkgs;
    (
      if skipHeavyPackages then
        [ ]
      else
        [
          # ── Browsers ──────────────────────────────────────────────────────────────
          chromium
          vscode

          # ── PDF / TeX ────────────────────────────────────────────────────────────
          zathura
          texlive.combined.scheme-medium
          texlab
          ltex-ls-plus

          # ── Learning ─────────────────────────────────────────────────────────────
          anki
        ]
    );
}

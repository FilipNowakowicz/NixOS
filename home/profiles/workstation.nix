{
  pkgs,
  skipHeavyPackages ? false,
  ...
}:
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

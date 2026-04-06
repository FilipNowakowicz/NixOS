{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # ── Browsers ─────────────────────────────────────────────
    chromium
    vscode

    # ── PDF / TeX ────────────────────────────────────────────
    zathura
    texlive.combined.scheme-medium
    texlab
    ltex-ls-plus
  ];
}

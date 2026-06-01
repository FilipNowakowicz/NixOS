{
  nixpkgs,
  system,
  ...
}:
let
  inherit (nixpkgs) lib;
  pkgs = nixpkgs.legacyPackages.${system};

  themeModulePath = ../../home/theme/module.nix;

  # The theme module only reads `config` and `lib`, so we can apply it directly
  # with a minimal stub and inspect the generated xdg.configFile set without
  # booting a full Home Manager evaluation.
  stubConfig = active: {
    themes.active = active;
    home.homeDirectory = "/home/test";
    xdg.configHome = "/home/test/.config";
  };

  evalThemed =
    active:
    (import themeModulePath {
      config = stubConfig active;
      inherit lib;
    }).config;

  evalOptions =
    (import themeModulePath {
      config = stubConfig "mono-mesh";
      inherit lib;
    }).options;

  files = (evalThemed "mono-mesh").xdg.configFile;

  monoTheme = import ../../home/theme/themes/mono-mesh.nix;
  varsText = files."themes/mono-mesh/vars".text;
  kittyText = files."themes/mono-mesh/kitty-theme.conf".text;

  failures = lib.runTests {
    # The runtime switcher sources this vars file instead of re-parsing .nix.
    testVarsFileGenerated = {
      expr = files ? "themes/mono-mesh/vars";
      expected = true;
    };

    # vars exposes the full color contract straight from the theme definition,
    # making Nix the single source of truth for the runtime switcher's colors.
    testVarsExposeColorContract = {
      expr = lib.all (line: lib.hasInfix line varsText) [
        "bg=${monoTheme.colors.bg}"
        "brown=${monoTheme.colors.brown}"
        "orange=${monoTheme.colors.orange}"
        "amber=${monoTheme.colors.amber}"
        "text=${monoTheme.colors.text}"
      ];
      expected = true;
    };

    # Kitty colors come from the per-theme ANSI palette, not a hardcoded
    # fallback — this is the divergence the old shell generator introduced.
    testKittyUsesAnsiPalette = {
      expr = lib.hasInfix "color9  #${monoTheme.ansiColors.color9}" kittyText;
      expected = true;
    };

    # active.nix is the single source for which theme is active.
    testActiveDefaultsFromActiveNix = {
      expr = evalOptions.themes.active.default;
      expected = (import ../../home/theme/active.nix).name;
    };
  };
in
if failures == [ ] then
  pkgs.runCommand "theme-module-tests" { } "touch $out"
else
  throw "tests/home/theme-module.nix tests failed:\n${lib.generators.toPretty { } failures}"

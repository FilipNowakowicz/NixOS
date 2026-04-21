_: {
  projectRootFile = "flake.nix";

  programs = {
    nixfmt.enable = true;
    shfmt.enable = true;
    prettier.enable = true;
  };

  settings.formatter.shfmt.includes = [ "scripts/**/*.sh" ];
  settings.formatter.prettier.includes = [
    "*.md"
    "**/*.md"
  ];
}

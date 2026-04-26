{
  nixpkgs,
  system,
  ...
}:
let
  pkgs = nixpkgs.legacyPackages.${system};
in
pkgs.runCommand "secrets-directory-check"
  {
    src = ../../.;
    nativeBuildInputs = with pkgs; [
      bash
      coreutils
      findutils
      gnugrep
    ];
  }
  ''
    cd "$src"
    bash ${../../scripts/check-secrets-directory.sh} --working-tree
    touch "$out"
  ''

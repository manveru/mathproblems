{
  description = "A flake for generating math problems";

  edition = 201909;

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs-channels/nixpkgs-unstable";
    utils.uri = "github:numtide/flake-utils";
    nix-whitelist.uri = "github:manveru/nix-whitelist";
  };

  outputs = { self, utils, nixpkgs, nix-whitelist }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        path = pkgs.lib.makeBinPath [ pkgs.asciidoc ];
        mathproblems = pkgs.crystal.buildCrystalPackage {
          pname = "mathproblems";
          version = "0.1";
          format = "crystal";
          src = nix-whitelist.lib.whitelist ./. [ ./src ];
          buildInputs = with pkgs; [ pkgconfig gmp makeWrapper ];
          crystalBinaries.mathproblems.src = "./src/math.cr";

          postInstall = ''
            wrapProgram $out/bin/mathproblems --prefix PATH : ${path}
          '';
        };
      in rec {
        defaultApp = mathproblems;
        defaultPackage = mathproblems;

        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [ crystal pkgconfig gmp asciidoc ];
        };
      });
}

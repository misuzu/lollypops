{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = inputs: {
    apps = inputs.flake-utils.lib.eachDefaultSystemMap (system: {
      default = { configFlake, ... }: inputs.flake-utils.lib.mkApp {
        drv = inputs.nixpkgs.legacyPackages.${system}.callPackage ./default.nix {
          inherit configFlake;
        };
      };
    });

    nixosModules = {
      default = inputs.self.nixosModules.nixos-deploy;
      nixos-deploy = import ./module.nix;
    };
  };
}

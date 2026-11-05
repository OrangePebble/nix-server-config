{
  description = "flake";

  inputs = {
    self.submodules = true;
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    quadlet-nix.url = "github:SEIAROTg/quadlet-nix";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pi = {
      url = "github:lukasl-dev/pi.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      # Common information about the system that may be used in multiple locations.
      # Using camelCase because that is the standard for options. kebab-case is for packages and files.
      vars = import ./lib/vars inputs;
      lib = (nixpkgs.lib.extend (_: _: home-manager.lib)).extend (import ./lib/lib);
    in
    {
      inherit lib;
      nixosConfigurations.${vars.hostname} = nixpkgs.lib.nixosSystem {
        inherit lib;
        system = vars.hostPlatform;
        modules = (lib.attrValues (lib.modulesIn ./modules)) ++ [
          ./lib/funcs
          ./lib/opts
        ];
        specialArgs = {
          inherit inputs;
          inherit vars;
        };
      };
    };
}

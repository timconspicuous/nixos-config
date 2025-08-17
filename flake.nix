{
  description = "Tim's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Zen Browser
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # GRUB2 Themes
    grub2-themes = {
      url = "github:vinceliuice/grub2-themes";
    };
  };

  outputs = inputs@{ self, nixpkgs, zen-browser, grub2-themes, ... }: {
    nixosConfigurations = {
      # Desktop machine
      desktop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          grub2-themes.nixosModules.default
          ./hosts/desktop
          ./modules/common.nix
          ./modules/desktop.nix
          ./modules/development.nix
          ./users/tim.nix
        ];
      };

      # Placeholder for homelab
      # nucbox = nixpkgs.lib.nixosSystem {
      #   system = "x86_64-linux";
      #   specialArgs = { inherit inputs; };
      #   modules = [
      #     ./hosts/server
      #     ./modules/common.nix
      #     ./modules/server.nix
      #     ./users/tim.nix
      #   ];
      # };
    };
  };
}

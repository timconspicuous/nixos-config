{
  description = "Tim's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    sops-nix.url = "github:Mic92/sops-nix";
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";

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

  outputs =
    inputs@{
      self,
      nixpkgs,
      zen-browser,
      grub2-themes,
      nix-minecraft,
      ...
    }:
    {
      nixosConfigurations = {
        # Desktop machine
        desktop = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            grub2-themes.nixosModules.default
            inputs.sops-nix.nixosModules.sops
            ./hosts/desktop
            ./modules/common.nix
            ./modules/desktop.nix
            ./modules/development.nix
            ./modules/minecraft.nix
            ./users/tim.nix
            nix-minecraft.nixosModules.minecraft-servers
            {
              nixpkgs.overlays = [ inputs.nix-minecraft.overlay ];
            }
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

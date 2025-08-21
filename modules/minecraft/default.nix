{
  config,
  lib,
  inputs,
  ...
}:

with lib;

let
  cfg = config.services.homelab.minecraft;
in
{
  imports = [
    inputs.nix-minecraft.nixosModules.minecraft-servers
    ./fabric.nix
  ];

  options.services.homelab.minecraft = {
    enable = mkEnableOption "Minecraft services";

    # Global minecraft settings
    eula = mkOption {
      type = types.bool;
      default = true;
      description = "Accept Minecraft EULA";
    };
  };

  config = mkIf cfg.enable {
    # Add the nix-minecraft overlay
    nixpkgs.overlays = [ inputs.nix-minecraft.overlay ];

    # Enable the base minecraft-servers service
    services.minecraft-servers = {
      enable = true;
      openFirewall = true;
      eula = cfg.eula;
    };
  };
}

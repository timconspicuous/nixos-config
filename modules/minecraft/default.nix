{ config, lib, ... }:

with lib;

let
  cfg = config.services.homelab.minecraft;
in
{
  imports = [
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
    # Enable the base minecraft-servers service
    services.minecraft-servers = {
      enable = true;
      eula = cfg.eula;
      openFirewall = false; # Handled by nginx module
    };
  };
}
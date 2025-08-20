{ config, lib, ... }:

with lib;

let
  cfg = config.services.homelab.auth;
in
{
  imports = [
    ./lldap.nix
    ./authelia.nix
  ];

  options.services.homelab.auth = {
    enable = mkEnableOption "Enable LLDAP and Authelia authentication services";

    domain = mkOption {
      type = types.str;
      default = "auth.local";
      description = "Domain for Authelia";
    };

    lldap.enable = mkEnableOption "Enable LLDAP" // {
      default = cfg.enable;
    };

    authelia.enable = mkEnableOption "Enable Authelia" // {
      default = cfg.enable;
    };
  };
}

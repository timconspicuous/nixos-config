{ config, lib, ... }:

with lib;

let
  cfg = config.services.homelab.homepage;
in
{
  options.services.homelab.homepage = {
    enable = mkEnableOption "Homepage Dashboard";

    listenPort = mkOption {
      type = types.port;
      default = 8082;
      description = "Port for homepage dashboard";
    };

    enableReverseProxy = mkOption {
      type = types.bool;
      default = true;
      description = "Enable reverse proxy for this service";
    };
  };

  config = mkIf cfg.enable {
    # Configure the actual homepage-dashboard service
    services.homepage-dashboard = {
      enable = true;
      bookmarks = import ./bookmarks.nix;
      settings = import ./settings.nix;
      services = import ./services.nix;
      listenPort = cfg.listenPort;
    };

    # Register with nginx only if reverse proxy is enabled
    services.myNginx.reverseProxies = mkIf cfg.enableReverseProxy {
      homepage = {
        subdomain = "home";
        target = "http://127.0.0.1:${toString cfg.listenPort}";
        websockets = true;
      };
    };
  };
}

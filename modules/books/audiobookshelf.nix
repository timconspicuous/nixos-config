{ config, lib, ... }:

with lib;

let
  cfg = config.services.homelab.audiobookshelf;
in
{
  options.services.homelab.audiobookshelf = {
    enable = mkEnableOption "Audiobookshelf";

    port = mkOption {
      type = types.port;
      default = 13378;
      description = "Port for audiobookshelf";
    };

    library = mkOption {
      type = types.str;
      default = "/var/lib/audiobookshelf";
      description = "Path to audiobookshelf library";
      example = "/path/to/audiolibrary";
    };

    enableReverseProxy = mkOption {
      type = types.bool;
      default = true;
      description = "Enable reverse proxy for this service";
    };
  };

  config = mkIf cfg.enable {
    services.audiobookshelf = {
      enable = true;
      openFirewall = true;
      host = "0.0.0.0";
      port = cfg.port;
      dataDir = cfg.library;
    };

    # Register with nginx only if reverse proxy is enabled
    services.homelab.nginx.reverseProxies = mkIf cfg.enableReverseProxy {
      audiobookshelf = {
        subdomain = "audiobookshelf";
        target = "http://127.0.0.1:${toString cfg.port}";
        websockets = true;
      };
    };
  };
}

{ config, lib, ... }:

with lib;

let
  cfg = config.services.homelab.calibre;
in
{
  options.services.homelab.calibre = {
    enable = mkEnableOption "Calibre Content Server";

    port = mkOption {
      type = types.port;
      default = 8880;
      description = "Port for content server";
    };

    libraries = mkOption {
      type = types.listOf lib.types.str;
      default = [ "/srv/media/books/calibre/tim" ];
      description = "List of library paths";
      example = [
        "/path/to/library1"
        "/path/to/library2"
      ];
    };

    enableReverseProxy = mkOption {
      type = types.bool;
      default = true;
      description = "Enable reverse proxy for this service";
    };
  };

  config = mkIf cfg.enable {
    services.calibre-server = {
      enable = true;
      host = "0.0.0.0";
      port = cfg.port;
      libraries = cfg.libraries;
      
      # Permission bodge because I use the client as "tim"
      user = "tim";
    };

    # Register with nginx only if reverse proxy is enabled
    services.homelab.nginx.reverseProxies = mkIf cfg.enableReverseProxy {
      calibre = {
        subdomain = "calibre";
        target = "http://127.0.0.1:${toString cfg.port}";
        websockets = true;
      };
    };
  };
}

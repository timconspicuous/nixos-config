{ config, lib, ... }:

with lib;

let
  cfg = config.services.homelab.nginx;
in
{
  options.services.homelab.nginx = {
    enable = mkEnableOption "custom nginx configuration";

    domain = mkOption {
      type = types.str;
      default = "timtinkers.online";
      description = "Base domain name";
    };

    # HTTP reverse proxy services
    reverseProxies = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            subdomain = mkOption {
              type = types.str;
              description = "Subdomain name";
            };
            target = mkOption {
              type = types.str;
              description = "Target URL to proxy to";
            };
            websockets = mkOption {
              type = types.bool;
              default = false;
              description = "Enable WebSocket support";
            };
            extraConfig = mkOption {
              type = types.str;
              default = "";
              description = "Extra nginx location configuration";
            };
          };
        }
      );
      default = { };
      description = "HTTP reverse proxy configurations";
    };
  };

  config = mkIf cfg.enable {
    services.nginx = {
      enable = true;

      # Generate virtualHosts from reverseProxies - only configured subdomains
      virtualHosts = mapAttrs (name: proxy: {
        serverName = "${proxy.subdomain}.${cfg.domain}";
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = proxy.target;
          proxyWebsockets = proxy.websockets;
          extraConfig = "proxy_ssl_server_name on;" + "proxy_pass_header Authorization;" + proxy.extraConfig;
        };
      }) cfg.reverseProxies;
    };

    networking.firewall.allowedTCPPorts = [
      80 # HTTP
      443 # HTTPS
    ];
  };
}

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

    # TCP/UDP stream proxies
    streamProxies = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            subdomain = mkOption {
              type = types.str;
              description = "Subdomain name for SSL preread";
            };
            target = mkOption {
              type = types.str;
              description = "Target host:port to proxy to";
            };
            port = mkOption {
              type = types.port;
              description = "Port to listen on";
            };
          };
        }
      );
      default = { };
      description = "TCP/UDP stream proxy configurations";
    };

    # Catch-all 404 page
    defaultSite = mkOption {
      type = types.bool;
      default = true;
      description = "Enable catch-all default site with 404";
    };
  };

  config = mkIf cfg.enable {
    services.nginx = {
      enable = true;

      # Generate virtualHosts from reverseProxies
      virtualHosts =
        # Individual reverse proxy hosts
        (
          mapAttrs (name: proxy: {
            serverName = "${proxy.subdomain}.${cfg.domain}";
            enableACME = true;
            forceSSL = true;
            locations."/" = {
              proxyPass = proxy.target;
              proxyWebsockets = proxy.websockets;
              extraConfig = "proxy_ssl_server_name on;" + "proxy_pass_header Authorization;" + proxy.extraConfig;
            };
          }) cfg.reverseProxies
        );

      # Default catch-all site disabled for now
      # //
      # (optionalAttrs cfg.defaultSite {
      #   "default.${cfg.domain}" = {
      #     serverName = "default.${cfg.domain}";
      #     default = true;
      #     enableACME = true;
      #     forceSSL = true;
      #     locations."/" = {
      #       return = "404";
      #       extraConfig = ''
      #         add_header Content-Type text/plain;
      #         return 404 "Service not found";
      #       '';
      #     };
      #   };
      # });

      # Generate stream configuration if we have stream proxies
      appendConfig = mkIf (cfg.streamProxies != { }) ''
        stream {
          # Map subdomain to backend server
          map $ssl_preread_server_name $backend_pool {
            ${concatStringsSep "\n    " (
              mapAttrsToList (name: proxy: "${proxy.subdomain}.${cfg.domain} ${proxy.target};") cfg.streamProxies
            )}
            # Default fallback
            default 127.0.0.1:1;
          }

          # Group stream proxies by port and create server blocks
          ${concatStringsSep "\n  " (
            mapAttrsToList (port: proxies: ''
              server {
                listen ${port};
                proxy_pass $backend_pool;
                proxy_timeout 1s;
                proxy_responses 1;
                ssl_preread on;
                error_log /var/log/nginx/stream_${port}_error.log;
              }
            '') (groupBy (proxy: toString proxy.port) (attrValues cfg.streamProxies))
          )}
        }
      '';
    };

    networking.firewall.allowedTCPPorts = [
      80 # HTTP
      443 # HTTPS
      25565 # Minecraft (external port for all servers)
    ];
  };
}

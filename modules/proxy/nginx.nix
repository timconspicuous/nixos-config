{ config, lib, ... }:

with lib;

let
  cfg = config.services.homelab.nginx;
  authCfg = config.services.homelab.auth.authelia;
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

      # Generate virtualHosts from reverseProxies
      virtualHosts = mapAttrs (
        name: proxy:
        let
          fullDomain = "${proxy.subdomain}.${cfg.domain}";
          isProtected = authCfg.enable && (builtins.elem fullDomain authCfg.protectedDomains);
        in
        {
          serverName = fullDomain;
          enableACME = true;
          forceSSL = true;

          locations = {
            "/" = {
              proxyPass = proxy.target;
              proxyWebsockets = proxy.websockets;
              extraConfig =
                "proxy_ssl_server_name on;"
                + "proxy_pass_header Authorization;"
                # Standard proxy headers
                + ''
                  proxy_set_header Host $host;
                  proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
                  proxy_set_header X-Forwarded-Proto $scheme;
                  proxy_set_header X-Forwarded-Host $http_host;
                  proxy_set_header X-Forwarded-URI $request_uri;
                  proxy_set_header X-Forwarded-For $remote_addr;
                  proxy_set_header X-Real-IP $remote_addr;
                ''
                + proxy.extraConfig
                +
                  # Add forward auth for protected domains - FIXED to use official method
                  (optionalString isProtected ''
                    # Send a subrequest to Authelia to verify authentication
                    auth_request /internal/authelia/authz;

                    # Save the upstream metadata response headers from Authelia to variables
                    auth_request_set $user $upstream_http_remote_user;
                    auth_request_set $groups $upstream_http_remote_groups;
                    auth_request_set $name $upstream_http_remote_name;
                    auth_request_set $email $upstream_http_remote_email;

                    # Inject the metadata response headers into the request to the backend
                    proxy_set_header Remote-User $user;
                    proxy_set_header Remote-Groups $groups;
                    proxy_set_header Remote-Name $name;
                    proxy_set_header Remote-Email $email;

                    # Modern method: Use the Location header from Authelia for redirection
                    auth_request_set $redirection_url $upstream_http_location;
                    error_page 401 =302 $redirection_url;
                  '');
            };
          }
          // (optionalAttrs isProtected {
            # Internal auth endpoint - FIXED to match official docs
            "/internal/authelia/authz" = {
              extraConfig = ''
                internal;
                proxy_pass http://127.0.0.1:${toString authCfg.port}/api/authz/auth-request;

                # Essential headers required by Authelia
                proxy_set_header X-Original-Method $request_method;
                proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
                proxy_set_header X-Forwarded-For $remote_addr;
                proxy_set_header Content-Length "";
                proxy_set_header Connection "";

                # Basic proxy configuration
                proxy_pass_request_body off;
                proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
                proxy_redirect http:// $scheme://;
                proxy_http_version 1.1;
                proxy_cache_bypass $cookie_session;
                proxy_no_cache $cookie_session;
                proxy_buffers 4 32k;
                client_body_buffer_size 128k;

                # Timeouts
                proxy_read_timeout 240;
                proxy_send_timeout 240;
                proxy_connect_timeout 240;
              '';
            };
          });
        }
      ) cfg.reverseProxies;
    };

    networking.firewall.allowedTCPPorts = [
      80 # HTTP
      443 # HTTPS
    ];
  };
}

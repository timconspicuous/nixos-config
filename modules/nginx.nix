{ ... }:

{
  services.nginx = {
    enable = true;

    virtualHosts."auth.timtinkers.online" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:9091";
        proxyWebsockets = true; # needed if you need to use WebSocket
        extraConfig =
          # required when the target is also TLS server with multiple hosts
          "proxy_ssl_server_name on;"
          +
            # required when the server wants to use HTTP Authentication
            "proxy_pass_header Authorization;";
      };
    };

    # TCP/UDP traffic
    appendConfig = ''
      stream {
        # Map subdomain to backend server
        map $ssl_preread_server_name $backend_pool {
          minecraft.timtinkers.online 127.0.0.1:25566;
          modded.timtinkers.online 127.0.0.1:25567;
          # Default fallback
          default 127.0.0.1:25566;
        }

        server {
          listen 25565;
          proxy_pass $backend_pool;
          proxy_timeout 1s;
          proxy_responses 1;

          # Enable SSL preread to get server name
          ssl_preread on;

          error_log /var/log/nginx/gameserver_error.log;
        }
      }
    '';
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
    25565
  ];
}

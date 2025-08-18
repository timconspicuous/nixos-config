{
  config,
  pkgs,
  lib,
  ...
}:

{
  services.nginx = {
    enable = true;
    
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

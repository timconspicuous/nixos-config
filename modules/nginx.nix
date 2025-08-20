{ ... }:

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

  # Optional: Add a simple nginx reverse proxy configuration
  # services.nginx = mkIf cfg.enable {
  #   enable = mkDefault true;
  #   virtualHosts = mkMerge [
  #     (mkIf cfg.lldap.enable {
  #       "lldap.${cfg.domain}" = {
  #         locations."/" = {
  #           proxyPass = "http://127.0.0.1:${toString cfg.lldap.port}";
  #           proxyWebsockets = true;
  #         };
  #       };
  #     })
  #     (mkIf cfg.authelia.enable {
  #       "${cfg.domain}" = {
  #         locations."/" = {
  #           proxyPass = "http://127.0.0.1:${toString cfg.authelia.port}";
  #           proxyWebsockets = true;
  #         };
  #       };
  #     })
  #   ];
  # };
}

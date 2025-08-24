{ config, lib, ... }:

with lib;

let
  cfg = config.services.homelab.pds;
in
{
  options.services.homelab.pds = {
    enable = mkEnableOption "AT Protocol PDS";

    port = mkOption {
      type = types.port;
      default = 3000;
      description = "Port for PDS";
    };

    domain = mkOption {
      type = types.str;
      default = "pds.timtinkers.online";
      description = "Domain for PDS";
    };

    enableReverseProxy = mkOption {
      type = types.bool;
      default = true;
      description = "Enable reverse proxy for this service";
    };
  };

  config = mkIf cfg.enable {
    # Create users and groups
    users.users.pds = {
      isSystemUser = true;
      group = "pds";
      home = "/var/lib/pds";
      createHome = true;
    };

    users.groups.pds = { };

    sops.secrets = {
      "pds_jwt_secret" = {
        sopsFile = ../secrets/common.yaml;
        owner = "pds";
        group = "pds";
        key = "pds/PDS_JWT_SECRET";
      };
      "pds_admin_password" = {
        sopsFile = ../secrets/common.yaml;
        owner = "pds";
        group = "pds";
        key = "pds/PDS_ADMIN_PASSWORD";
      };
      "pds_plc_rotation_key" = {
        sopsFile = ../secrets/common.yaml;
        owner = "pds";
        group = "pds";
        key = "pds/PDS_PLC_ROTATION_KEY_K256_PRIVATE_KEY_HEX";
      };
    };

    sops.templates."pds-env" = {
      content = ''
        PDS_JWT_SECRET=${config.sops.placeholder."pds_jwt_secret"}
        PDS_ADMIN_PASSWORD=${config.sops.placeholder."pds_admin_password"}
        PDS_PLC_ROTATION_KEY_K256_PRIVATE_KEY_HEX=${config.sops.placeholder."pds_plc_rotation_key"}
      '';
      owner = "pds";
      group = "pds";
    };

    # PDS Service Configuration
    services.pds = {
      enable = true;
      pdsadmin.enable = true;
      environmentFiles = [ config.sops.templates."pds-env".path ];
      settings = {
        PDS_PORT = cfg.port;
        PDS_DATA_DIRECTORY = "/var/lib/pds";
        PDS_CRAWLERS = "https://bsky.network";
        LOG_ENABLED = "true";
        PDS_HOSTNAME = "pds.timtinkers.online";
        PDS_DID_PLC_URL = "https://plc.directory";
        PDS_CONTACT_EMAIL_ADDRESS = "git@timtinkers.online";
        PDS_PRIVACY_POLICY_URL = "https://timtinkers.online";
        PDS_TERMS_OF_SERVICE_URL = "https://timtinkers.online";
        PDS_ACCEPTING_REPO_IMPORTS = "true";
      };
    };

    # Networking - Open required ports
    networking.firewall.allowedTCPPorts = [ cfg.port ];

    # Register with nginx only if reverse proxy is enabled
    services.homelab.nginx.reverseProxies = mkIf cfg.enableReverseProxy {
      pds = {
        subdomain = "pds";
        target = "http://127.0.0.1:${toString cfg.port}";
        websockets = true;
      };
    };
  };
}

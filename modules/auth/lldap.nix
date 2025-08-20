{ config, lib, ... }:

with lib;

let
  cfg = config.services.homelab.auth.lldap;
  authCfg = config.services.homelab.auth;
in
{
  options.services.homelab.auth.lldap = {
    enable = mkEnableOption "Enable LLDAP";

    port = mkOption {
      type = types.port;
      default = 17170;
      description = "Port for LLDAP web interface";
    };

    ldapPort = mkOption {
      type = types.port;
      default = 3890;
      description = "Port for LDAP server";
    };

    baseDn = mkOption {
      type = types.str;
      default = "dc=example,dc=com";
      description = "Base DN for LDAP";
    };

    adminUsername = mkOption {
      type = types.str;
      default = "lldap_admin";
      description = "LLDAP admin username";
    };
  };

  config = mkIf cfg.enable {
    # Create users and groups
    users.users.lldap = {
      isSystemUser = true;
      group = "lldap";
      home = "/var/lib/lldap";
      createHome = true;
    };

    users.groups.lldap = { };

    # SOPS secrets configuration
    sops.secrets = {
      "lldap-jwt-secret" = {
        sopsFile = ../secrets/common.yaml;
        key = "auth/lldap-jwt-secret";
        owner = "lldap";
        mode = "0400";
      };
      "lldap-ldap-user-password" = {
        sopsFile = ../secrets/common.yaml;
        key = "auth/lldap-ldap-user-password";
        owner = "lldap";
        group = "authelia-main"; # Allow authelia-main to read it
        mode = "0440"; # Allow group to read
      };
    };

    # LLDAP Service Configuration
    services.lldap = {
      enable = true;
      settings = {
        http_port = cfg.port;
        ldap_port = cfg.ldapPort;
        ldap_base_dn = cfg.baseDn;
        ldap_user_email = "${cfg.adminUsername}@${authCfg.domain}";

        # Database settings (using SQLite by default)
        database_url = "sqlite:///var/lib/lldap/users.db";

        # Bind configuration
        http_host = "0.0.0.0";
        ldap_host = "0.0.0.0";

        # TLS settings (adjust as needed)
        ldaps_options = {
          enabled = false;
          port = 6360;
        };
      };

      # Use environment variables for secrets
      environment = {
        LLDAP_JWT_SECRET_FILE = config.sops.secrets."lldap-jwt-secret".path;
        LLDAP_LDAP_USER_PASS_FILE = config.sops.secrets."lldap-ldap-user-password".path;
      };
    };

    # Ensure state directories exist with proper permissions
    systemd.tmpfiles.rules = [
      "d /var/lib/lldap 0750 lldap lldap -"
    ];

    # System service configuration
    systemd.services.lldap = {
      # DynamicUser screws up sops-nix ownership because
      # the user doesn't exist outside of runtime.
      serviceConfig.DynamicUser = mkForce false;
    };

    # Networking - Open required ports
    networking.firewall.allowedTCPPorts = [
      cfg.port
      cfg.ldapPort
    ];
  };
}

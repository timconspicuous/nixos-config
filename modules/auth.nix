{ config, lib, ... }:

with lib;

let
  cfg = config.services.homelab.auth;
in
{
  options.services.homelab.auth = {
    enable = mkEnableOption "Enable LLDAP and Authelia authentication services";

    domain = mkOption {
      type = types.str;
      default = "auth.local";
      description = "Domain for Authelia";
    };

    lldap = {
      enable = mkEnableOption "Enable LLDAP" // {
        default = cfg.enable;
      };

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
        default = "admin";
        description = "LLDAP admin username";
      };
    };

    authelia = {
      enable = mkEnableOption "Enable Authelia" // {
        default = cfg.enable;
      };

      port = mkOption {
        type = types.port;
        default = 9091;
        description = "Port for Authelia";
      };

      protectedDomains = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "List of domains to protect with Authelia";
        example = [
          "calibre.local"
          "nextcloud.local"
        ];
      };
    };
  };

  config = mkIf cfg.enable {
    # Create users and groups first
    users.users.lldap = mkIf cfg.lldap.enable {
      isSystemUser = true;
      group = "lldap";
      home = "/var/lib/lldap";
      createHome = true;
    };

    users.groups.lldap = mkIf cfg.lldap.enable { };

    # Create authelia user (NixOS creates authelia-{instance} automatically, but we need to ensure proper user exists)
    # The actual service runs as authelia-main for the "main" instance
    users.users.authelia-main = mkIf cfg.authelia.enable {
      isSystemUser = true;
      group = "authelia-main";
      home = "/var/lib/authelia-main";
      createHome = true;
    };

    users.groups.authelia-main = mkIf cfg.authelia.enable { };

    # SOPS configuration - now that users exist
    sops.secrets = {
      "authelia-jwt-secret" = mkIf cfg.authelia.enable {
        sopsFile = ../secrets/common.yaml;
        key = "auth/authelia-jwt-secret";
        owner = "authelia-main";
        group = "authelia-main";
        mode = "0400";
      };
      "authelia-session-secret" = mkIf cfg.authelia.enable {
        sopsFile = ../secrets/common.yaml;
        key = "auth/authelia-session-secret";
        owner = "authelia-main";
        group = "authelia-main";
        mode = "0400";
      };
      "authelia-storage-encryption-key" = mkIf cfg.authelia.enable {
        sopsFile = ../secrets/common.yaml;
        key = "auth/authelia-storage-encryption-key";
        owner = "authelia-main";
        group = "authelia-main";
        mode = "0400";
      };
      "lldap-jwt-secret" = mkIf cfg.lldap.enable {
        sopsFile = ../secrets/common.yaml;
        key = "auth/lldap-jwt-secret";
        owner = "lldap";
        mode = "0400";
      };
      "lldap-ldap-user-password" = mkIf cfg.lldap.enable {
        sopsFile = ../secrets/common.yaml;
        key = "auth/lldap-ldap-user-password";
        owner = "lldap";
        group = "authelia-main"; # Allow authelia-main to read it
        mode = "0440"; # Allow group to read
      };
    };

    # LLDAP Configuration
    services.lldap = mkIf cfg.lldap.enable {
      enable = true;
      settings = {
        http_port = cfg.lldap.port;
        ldap_port = cfg.lldap.ldapPort;
        ldap_base_dn = cfg.lldap.baseDn;

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

    # Authelia Configuration
    services.authelia.instances.main = mkIf cfg.authelia.enable {
      enable = true;

      # Load SOPS secrets
      secrets = {
        jwtSecretFile = config.sops.secrets."authelia-jwt-secret".path;
        sessionSecretFile = config.sops.secrets."authelia-session-secret".path;
        storageEncryptionKeyFile = config.sops.secrets."authelia-storage-encryption-key".path;
      };

      # Use environment variables for LDAP password - removed since we're using file: syntax
      # environmentVariables = {
      #   AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD_FILE = config.sops.secrets."lldap-ldap-user-password".path;
      # };

      settings = {
        # Server configuration
        server = {
          address = "tcp://0.0.0.0:${toString cfg.authelia.port}";
          asset_path = "";
        };

        # Logging
        log = {
          level = "info";
          format = "text";
        };

        # Session configuration - using new format
        session = {
          name = "authelia_session";
          same_site = "lax";
          expiration = "1h";
          inactivity = "5m";
          remember_me = "1M";
          cookies = [
            {
              domain = cfg.domain;
              authelia_url = "https://${cfg.domain}";
              default_redirection_url = "https://www.${cfg.domain}"; # Must be different from authelia_url
            }
          ];
        };

        # Storage configuration (SQLite)
        storage = {
          local = {
            path = "/var/lib/authelia-main/db.sqlite3";
          };
        };

        # LDAP Authentication Backend (connecting to LLDAP)
        authentication_backend = {
          ldap = {
            implementation = "custom";
            address = "ldap://127.0.0.1:${toString cfg.lldap.ldapPort}";
            timeout = "5s";
            start_tls = false;
            tls = {
              skip_verify = true;
              minimum_version = "TLS1.2";
            };
            base_dn = cfg.lldap.baseDn;
            additional_users_dn = "ou=people";
            users_filter = "(&({username_attribute}={input})(objectClass=person))";
            additional_groups_dn = "ou=groups";
            groups_filter = "(member={dn})";
            attributes = {
              group_name = "cn";
              mail = "mail";
              display_name = "displayName";
              username = "uid";
            };
            user = "uid=${cfg.lldap.adminUsername},ou=people,${cfg.lldap.baseDn}";
            password = "file://${config.sops.secrets."lldap-ldap-user-password".path}";
          };
        };

        # Access Control Rules
        access_control = {
          default_policy = "deny";
          rules = [
            {
              domain = [ cfg.domain ];
              policy = "bypass";
            }
          ]
          ++ (map (domain: {
            domain = [ domain ];
            policy = "two_factor";
          }) cfg.authelia.protectedDomains);
        };

        # Regulation (brute force protection)
        regulation = {
          max_retries = 3;
          find_time = "2m";
          ban_time = "5m";
        };

        # TOTP Configuration
        totp = {
          issuer = "authelia.com";
          period = 30;
          skew = 1;
        };

        # WebAuthn Configuration
        webauthn = {
          display_name = "Authelia";
          attestation_conveyance_preference = "indirect";
          selection_criteria = {
            user_verification = "preferred";
          };
          timeout = "60s";
        };

        # Identity validation configuration - removed because it's handled by secrets section
        # identity_validation = {
        #   reset_password = {
        #     jwt_secret = "file://${config.sops.secrets."authelia-jwt-secret".path}";
        #   };
        # };

        # Notifier (file-based for simplicity)
        notifier = {
          filesystem = {
            filename = "/var/lib/authelia-main/notification.txt";
          };
        };
      };
    };

    # Ensure state directories exist with proper permissions
    systemd.tmpfiles.rules = mkMerge [
      (mkIf cfg.lldap.enable [
        "d /var/lib/lldap 0750 lldap lldap -"
      ])
      (mkIf cfg.authelia.enable [
        "d /var/lib/authelia-main 0750 authelia-main authelia-main -"
      ])
    ];

    # System service dependencies
    systemd.services = mkMerge [
      (mkIf cfg.authelia.enable {
        authelia-main = {
          after = [ "lldap.service" ];
          wants = [ "lldap.service" ];
        };
      })
    ];

    # Networking - Open required ports
    networking.firewall.allowedTCPPorts = mkMerge [
      (mkIf cfg.lldap.enable [
        cfg.lldap.port
        cfg.lldap.ldapPort
      ])
      (mkIf cfg.authelia.enable [ cfg.authelia.port ])
    ];
  };
}

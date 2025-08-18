{
  config,
  lib,
  pkgs,
  ...
}:

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
    # SOPS configuration
    sops.secrets = {
      "authelia-jwt-secret" = {
        sopsFile = ./secrets/common.yaml;
        owner = "authelia";
        group = "authelia";
        mode = "0400";
      };
      "authelia-session-secret" = {
        sopsFile = ./secrets/common.yaml;
        owner = "authelia";
        mode = "0400";
      };
      "authelia-storage-encryption-key" = {
        sopsFile = ./secrets/common.yaml;
        owner = "authelia";
        mode = "0400";
      };
      "lldap-jwt-secret" = {
        sopsFile = ./secrets/common.yaml;
        owner = "lldap";
        mode = "0400";
      };
      "lldap-ldap-user-password" = {
        sopsFile = ./secrets/common.yaml;
        owner = "lldap";
        mode = "0400";
      };
    };

    # LLDAP Configuration
    services.lldap = mkIf cfg.lldap.enable {
      enable = true;
      settings = {
        # Load SOPS secrets
        jwt_secret = config.sops.secrets.lldap-jwt-secret.path;
        ldap_user_pass = config.sops.secrets.lldap-ldap-user-password.path;

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
    };

    # Authelia Configuration
    services.authelia.instances.main = mkIf cfg.authelia.enable {
      enable = true;

      # Load SOPS secrets
      secrets = {
        jwtSecretFile = config.sops.secrets.authelia-jwt-secret.path;
        storageEncryptionKeyFile = config.sops.secrets.authelia-storage-encryption-key.path;
        sessionSecretFile = config.sops.secrets.authelia-session-secret.path;
      };

      settings = {
        # Server configuration
        server = {
          host = "0.0.0.0";
          port = cfg.authelia.port;
          path = "";
          asset_path = "";
        };

        # Logging
        log = {
          level = "info";
          format = "text";
        };

        # Default redirection URL
        default_redirection_url = "https://${cfg.domain}";

        # Session configuration
        session = {
          name = "authelia_session";
          domain = cfg.domain;
          same_site = "lax";
          expiration = "1h";
          inactivity = "5m";
          remember_me_duration = "1M";
        };

        # Storage configuration (SQLite)
        storage = {
          local = {
            path = "/var/lib/authelia/db.sqlite3";
          };
        };

        # LDAP Authentication Backend (connecting to LLDAP)
        authentication_backend = {
          ldap = {
            implementation = "custom";
            url = "ldap://127.0.0.1:${toString cfg.lldap.ldapPort}";
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
            group_name_attribute = "cn";
            mail_attribute = "mail";
            display_name_attribute = "displayName";
            user = "uid=${cfg.lldap.adminUsername},ou=people,${cfg.lldap.baseDn}";
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
          user_verification = "preferred";
          timeout = "60s";
        };

        # Notifier (file-based for simplicity)
        notifier = {
          filesystem = {
            filename = "/var/lib/authelia/notification.txt";
          };
        };
      };
    };

    # Networking - Open required ports
    networking.firewall.allowedTCPPorts = mkMerge [
      (mkIf cfg.lldap.enable [
        cfg.lldap.port
        cfg.lldap.ldapPort
      ])
      (mkIf cfg.authelia.enable [ cfg.authelia.port ])
    ];

    # System users and groups
    users.users.lldap = mkIf cfg.lldap.enable {
      isSystemUser = true;
      group = "lldap";
      home = "/var/lib/lldap";
      createHome = true;
    };

    users.groups.lldap = mkIf cfg.lldap.enable { };

    # Ensure state directories exist with proper permissions
    systemd.tmpfiles.rules = mkMerge [
      (mkIf cfg.lldap.enable [
        "d /var/lib/lldap 0750 lldap lldap -"
      ])
      (mkIf cfg.authelia.enable [
        "d /var/lib/authelia 0750 authelia authelia -"
      ])
    ];

    # Optional: Add a simple nginx reverse proxy configuration
    services.nginx = mkIf cfg.enable {
      enable = mkDefault true;
      virtualHosts = mkMerge [
        (mkIf cfg.lldap.enable {
          "lldap.${cfg.domain}" = {
            locations."/" = {
              proxyPass = "http://127.0.0.1:${toString cfg.lldap.port}";
              proxyWebsockets = true;
            };
          };
        })
        (mkIf cfg.authelia.enable {
          "${cfg.domain}" = {
            locations."/" = {
              proxyPass = "http://127.0.0.1:${toString cfg.authelia.port}";
              proxyWebsockets = true;
            };
          };
        })
      ];
    };
  };
}

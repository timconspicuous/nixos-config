{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.homelab.auth;

  # Read secrets from files (relative to flake root)
  lldapJwtSecret = builtins.readFile ./secrets/lldap-jwt-secret;
  lldapLdapUserPassword = builtins.readFile ./secrets/lldap-ldap-user-password;
  autheliaJwtSecret = builtins.readFile ./secrets/authelia-jwt-secret;
  autheliaSessionSecret = builtins.readFile ./secrets/authelia-session-secret;
  autheliaStorageEncryptionKey = builtins.readFile ./secrets/authelia-storage-encryption-key;

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
    # LLDAP Configuration
    services.lldap = mkIf cfg.lldap.enable {
      enable = true;
      settings = {
        http_port = cfg.lldap.port;
        ldap_port = cfg.lldap.ldapPort;

        ldap_base_dn = cfg.lldap.baseDn;

        # JWT secret for session management
        jwt_secret = lldapJwtSecret;

        # LDAP user password
        ldap_user_pass = lldapLdapUserPassword;

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

        # JWT configuration
        jwt_secret = autheliaJwtSecret;

        # Default redirection URL
        default_redirection_url = "https://${cfg.domain}";

        # Session configuration
        session = {
          name = "authelia_session";
          domain = cfg.domain;
          same_site = "lax";
          secret = autheliaSessionSecret;
          expiration = "1h";
          inactivity = "5m";
          remember_me_duration = "1M";
        };

        # Storage configuration (SQLite)
        storage = {
          local = {
            path = "/var/lib/authelia/db.sqlite3";
          };
          encryption_key = autheliaStorageEncryptionKey;
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
            password = lldapLdapUserPassword;
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

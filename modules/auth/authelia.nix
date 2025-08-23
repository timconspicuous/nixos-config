{ config, lib, ... }:

with lib;

let
  cfg = config.services.homelab.auth.authelia;
  lldapCfg = config.services.homelab.auth.lldap;
  nginxCfg = config.services.homelab.nginx;
in
{
  options.services.homelab.auth.authelia = {
    enable = mkEnableOption "Authelia";

    port = mkOption {
      type = types.port;
      default = 9091;
      description = "Port for Authelia";
    };

    domain = mkOption {
      type = types.str;
      default = "auth.local";
      description = "Domain for Authelia";
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

    enableReverseProxy = mkOption {
      type = types.bool;
      default = true;
      description = "Enable reverse proxy for this service";
    };
  };

  config = mkIf cfg.enable {
    # Create authelia user
    users.users.authelia-main = {
      isSystemUser = true;
      group = "authelia-main";
      home = "/var/lib/authelia-main";
      createHome = true;
    };

    users.groups.authelia-main = { };

    # SOPS secrets configuration
    sops.secrets = {
      "authelia-jwt-secret" = {
        sopsFile = ../../secrets/common.yaml;
        key = "auth/authelia-jwt-secret";
        owner = "authelia-main";
        group = "authelia-main";
        mode = "0400";
      };
      "authelia-session-secret" = {
        sopsFile = ../../secrets/common.yaml;
        key = "auth/authelia-session-secret";
        owner = "authelia-main";
        group = "authelia-main";
        mode = "0400";
      };
      "authelia-storage-encryption-key" = {
        sopsFile = ../../secrets/common.yaml;
        key = "auth/authelia-storage-encryption-key";
        owner = "authelia-main";
        group = "authelia-main";
        mode = "0400";
      };
    };

    # Authelia Configuration
    services.authelia.instances.main = {
      enable = true;

      # Load SOPS secrets
      secrets = {
        jwtSecretFile = config.sops.secrets."authelia-jwt-secret".path;
        sessionSecretFile = config.sops.secrets."authelia-session-secret".path;
        storageEncryptionKeyFile = config.sops.secrets."authelia-storage-encryption-key".path;
      };

      # Use environment variables for LDAP password
      environmentVariables = {
        AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD_FILE =
          config.sops.secrets."lldap-ldap-user-password".path;
      };

      settings = {
        # Server configuration
        server = {
          address = "tcp://0.0.0.0:${toString cfg.port}";
          asset_path = "";
          # Add the endpoints configuration for auth-request
          endpoints = {
            authz = {
              "auth-request" = {
                implementation = "AuthRequest";
              };
            };
          };
        };

        # Logging
        log = {
          level = "info";
          format = "text";
        };

        # Session configuration
        session = {
          # Global session settings
          name = "authelia_session";
          same_site = "lax";
          expiration = "1h";
          inactivity = "5m";
          remember_me = "1M";

          cookies = [
            {
              domain = "${nginxCfg.domain}"; # "timtinkers.online" - no dot prefix
              authelia_url = "https://${cfg.domain}"; # "https://auth.timtinkers.online"
              default_redirection_url = "https://home.${nginxCfg.domain}";
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
            address = "ldap://127.0.0.1:${toString lldapCfg.ldapPort}";
            timeout = "5s";
            start_tls = false;
            tls = {
              skip_verify = true;
              minimum_version = "TLS1.2";
            };
            base_dn = lldapCfg.baseDn;
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
            user = "uid=${lldapCfg.adminUsername},ou=people,${lldapCfg.baseDn}";
          };
        };

        # Access Control Rules
        access_control = {
          default_policy = "deny";
          rules = [
            # Allow Authelia's own domain
            {
              domain = [ cfg.domain ];
              policy = "bypass";
            }
            # Allow internal health checks and API calls
            {
              domain = [
                "localhost"
                "127.0.0.1"
              ];
              policy = "bypass";
            }
          ]
          ++ (map (domain: {
            domain = [ domain ];
            policy = "one_factor";
          }) cfg.protectedDomains);
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

        # WebAuthn Configuration - FIXED
        webauthn = {
          display_name = "Authelia";
          attestation_conveyance_preference = "indirect";
          timeout = "60s";
          selection_criteria = {
            user_verification = "preferred";
          };
        };

        # Notifier (file-based for simplicity)
        notifier = {
          filesystem = {
            filename = "/var/lib/authelia-main/notification.txt";
          };
        };
      };
    };

    # Ensure state directories exist with proper permissions
    systemd.tmpfiles.rules = [
      "d /var/lib/authelia-main 0750 authelia-main authelia-main -"
    ];

    # System service dependencies
    systemd.services.authelia-main = {
      after = [ "lldap.service" ];
      wants = [ "lldap.service" ];
    };

    # Networking - Open required ports
    networking.firewall.allowedTCPPorts = [ cfg.port ];

    # Register with nginx only if reverse proxy is enabled
    services.homelab.nginx.reverseProxies = mkIf cfg.enableReverseProxy {
      authelia = {
        subdomain = "auth";
        target = "http://127.0.0.1:${toString cfg.port}";
        websockets = true;
      };
    };
  };
}

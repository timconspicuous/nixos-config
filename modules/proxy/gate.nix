{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.homelab.gate;

  # Generate Gate YAML configuration
  routesList = mapAttrsToList (name: proxy: {
    host = "${proxy.subdomain}.${cfg.domain}";
    backend = proxy.target;
    fallback = {
      motd = "§cServer is offline.\n§e Contact Tim or check back later!";
      version = {
        name = "§cTry again later!";
        protocol = -1;
      };
    }
    // optionalAttrs (cfg.favicon != null) {
      favicon = cfg.favicon;
    };
  }) cfg.reverseProxies;

  gateConfig = {
    config = {
      bind = "${cfg.bind}:${toString cfg.port}";
      onlineMode = true;
      debug = cfg.logLevel == "debug";
      connectionTimeout = cfg.connectionTimeout;
      readTimeout = cfg.readTimeout;
      lite = {
        enabled = true;
        routes = routesList;
      };
    };
  };

  configFile = pkgs.writeTextFile {
    name = "gate-config.yml";
    text = pkgs.lib.generators.toYAML { } gateConfig;
  };

in
{
  options.services.homelab.gate = {
    enable = mkEnableOption "Gate Minecraft reverse proxy server";

    bind = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "Address to bind the gate server to";
    };

    port = mkOption {
      type = types.port;
      default = 25565;
      description = "Port to bind the gate server to";
    };

    reverseProxies = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            subdomain = mkOption {
              type = types.str;
              description = "Subdomain for this Minecraft server";
              example = "survival";
            };

            target = mkOption {
              type = types.str;
              description = "Target address and port for the Minecraft server";
              example = "127.0.0.1:25566";
            };
          };
        }
      );
      default = { };
      description = "Reverse proxy configurations for Minecraft servers";
      example = literalExpression ''
        {
          survival = {
            subdomain = "survival";
            target = "127.0.0.1:25566";
          };
          creative = {
            subdomain = "creative";
            target = "127.0.0.1:25567";
          };
        }
      '';
    };

    domain = mkOption {
      type = types.str;
      default = "example.com";
      description = "Base domain for subdomains";
      example = "example.com";
    };

    connectionTimeout = mkOption {
      type = types.str;
      default = "5s";
      description = "Time to wait when connecting to backend servers";
    };

    readTimeout = mkOption {
      type = types.str;
      default = "30s";
      description = "Time to wait for data from backend servers";
    };

    logLevel = mkOption {
      type = types.enum [
        "debug"
        "info"
        "warn"
        "error"
      ];
      default = "info";
      description = "Log level for gate";
    };

    favicon = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to a PNG favicon file (64x64 recommended)";
      example = "./favicon.png";
    };

    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra command line arguments to pass to gate";
      example = [
        "--debug"
        "--metrics-port=8080"
      ];
    };
  };

  config = mkIf cfg.enable {
    # Create gate user and group
    users.users.gate = {
      group = "gate";
      isSystemUser = true;
      description = "Gate Minecraft reverse proxy user";
    };

    users.groups.gate = { };

    # Always open firewall
    networking.firewall.allowedTCPPorts = [ cfg.port ];

    # SystemD service
    systemd.services.gate = {
      description = "Gate Minecraft Reverse Proxy";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = "gate";
        Group = "gate";
        Restart = "always";
        RestartSec = "5";

        # Security settings
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ "/var/lib/gate" ];

        # Environment
        Environment = [
          "GATE_LOG_LEVEL=${cfg.logLevel}"
        ];

        # Command
        ExecStart = concatStringsSep " " (
          [
            "${pkgs.gate}/bin/gate"
            "--config=${configFile}"
          ]
          ++ cfg.extraArgs
        );
      };

      # Ensure config is valid before starting
      preStart = ''
        echo "Starting Gate with config:"
        cat ${configFile}
      '';
    };

    # Create state directory
    systemd.tmpfiles.rules = [
      "d /var/lib/gate 0755 gate gate -"
    ];

    # Validation
    assertions = [
      {
        assertion = cfg.reverseProxies != { };
        message = "At least one reverse proxy must be configured for gate to be useful";
      }
      {
        assertion = all (proxy: proxy.subdomain != "") (attrValues cfg.reverseProxies);
        message = "All reverse proxies must have a non-empty subdomain";
      }
      {
        assertion = all (proxy: proxy.target != "") (attrValues cfg.reverseProxies);
        message = "All reverse proxies must have a non-empty target";
      }
    ];

    # Warnings for common misconfigurations
    warnings =
      optional (cfg.bind == "127.0.0.1" && cfg.reverseProxies != { })
        "Gate is bound to localhost but has reverse proxies configured. Consider binding to 0.0.0.0 for external access"
      ++
        optional (cfg.domain == "example.com")
          "Gate is using the default domain 'example.com'. Set services.homelab.gate.domain to your actual domain";
  };
}

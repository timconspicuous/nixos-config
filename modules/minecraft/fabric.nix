{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.homelab.minecraft.fabric;
  minecraftCfg = config.services.homelab.minecraft;
in
{
  options.services.homelab.minecraft.fabric = {
    enable = mkEnableOption "Fabric Minecraft server";

    port = mkOption {
      type = types.port;
      default = 25566;
      description = "Port for Fabric server";
    };

    enableReverseProxy = mkOption {
      type = types.bool;
      default = true;
      description = "Enable reverse proxy for this server";
    };

    subdomain = mkOption {
      type = types.str;
      default = "minecraft";
      description = "Subdomain for this server";
    };

    # Server configuration options
    maxMemory = mkOption {
      type = types.str;
      default = "6G";
      description = "Maximum memory allocation";
    };

    minMemory = mkOption {
      type = types.str;
      default = "2G";
      description = "Minimum memory allocation";
    };

    maxPlayers = mkOption {
      type = types.int;
      default = 5;
      description = "Maximum number of players";
    };

    difficulty = mkOption {
      type = types.int;
      default = 3;
      description = "Server difficulty (0-3)";
    };

    motd = mkOption {
      type = types.str;
      default = "tim's NixOS server";
      description = "Server message of the day";
    };

    whitelist = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Player whitelist mapping names to UUIDs";
    };

    mods = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            url = mkOption {
              type = types.str;
              description = "Download URL for the mod";
            };
            sha512 = mkOption {
              type = types.str;
              description = "SHA512 hash of the mod file";
            };
          };
        }
      );
      default = { };
      description = "Mods to install on the server";
    };

    # Fabric-specific options
    fabricVersion = mkOption {
      type = types.str;
      default = "1_21_8";
      description = "Fabric server version";
    };

    loaderVersion = mkOption {
      type = types.str;
      default = "0.17.2";
      description = "Fabric loader version";
    };
  };

  config = mkIf (minecraftCfg.enable && cfg.enable) {
    # Configure the actual minecraft server
    services.minecraft-servers.servers.fabric = {
      enable = true;

      # Specify the custom minecraft server package
      package = pkgs.fabricServers."fabric-${cfg.fabricVersion}".override {
        loaderVersion = cfg.loaderVersion;
      };

      # Create mod symlinks from our mod definitions
      symlinks = mkIf (cfg.mods != { }) {
        mods = pkgs.linkFarmFromDrvs "mods" (
          mapAttrsToList (
            name: mod:
            pkgs.fetchurl {
              url = mod.url;
              sha512 = mod.sha512;
            }
          ) cfg.mods
        );
      };

      jvmOpts = "-Xms${cfg.minMemory} -Xmx${cfg.maxMemory} -Dfml.readTimeout=180";

      serverProperties = {
        server-port = cfg.port;
        difficulty = cfg.difficulty;
        gamemode = 0;
        max-players = cfg.maxPlayers;
        motd = cfg.motd;
        white-list = cfg.whitelist != { };
      };

      whitelist = cfg.whitelist;
    };

    # Register stream proxy with nginx only if reverse proxy is enabled
    services.homelab.nginx.streamProxies = mkIf cfg.enableReverseProxy {
      fabric = {
        subdomain = cfg.subdomain;
        target = "127.0.0.1:${toString cfg.port}";
        port = 25565;
      };
    };
  };
}

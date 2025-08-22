{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.homelab.homepage;

  # Helper function to convert YAML to JSON and import
  importYaml =
    yamlFile:
    let
      jsonFile =
        pkgs.runCommand "yaml-to-json"
          {
            buildInputs = [ pkgs.yq-go ];
          }
          ''
            yq eval -o=json ${yamlFile} > $out
          '';
    in
    builtins.fromJSON (builtins.readFile jsonFile);
in
{
  options.services.homelab.homepage = {
    enable = mkEnableOption "Homepage Dashboard";

    listenPort = mkOption {
      type = types.port;
      default = 8082;
      description = "Port for homepage dashboard";
    };

    enableReverseProxy = mkOption {
      type = types.bool;
      default = true;
      description = "Enable reverse proxy for this service";
    };

    allowedHosts = mkOption {
      type = types.listOf types.str;
      default = [
        "localhost:8082"
        "127.0.0.1:8082"
        "home.${config.services.homelab.nginx.domain}"
      ];
      description = "List of allowed hosts for the homepage dashboard";
    };
  };

  config = mkIf cfg.enable {
    # Configure the actual homepage-dashboard service
    services.homepage-dashboard = {
      enable = true;
      openFirewall = true;
      bookmarks = importYaml ./bookmarks.yaml;
      settings = importYaml ./settings.yaml;
      services = importYaml ./services.yaml;
      widgets = importYaml ./widgets.yaml;
      listenPort = cfg.listenPort;
      allowedHosts = concatStringsSep "," cfg.allowedHosts;
    };

    # Register with nginx only if reverse proxy is enabled
    services.homelab.nginx.reverseProxies = mkIf cfg.enableReverseProxy {
      homepage = {
        subdomain = "home";
        target = "http://127.0.0.1:${toString cfg.listenPort}";
        websockets = true;
      };
    };
  };
}

{ lib, ... }:

with lib;

{
  # Configure the homepage-dashboard service
  config = {
    services.homepage-dashboard = {
      enable = mkEnableOption "Start Homepage Dashbpard";
      bookmarks = import ./bookmarks.nix;
      settings = import ./settings.nix;
      services = import ./services.nix;
    };
  };
}

{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Minecraft server settings
  services.minecraft-servers = {
    enable = true;
    eula = true;
    openFirewall = true;
    declarative = true;

    servers.fabric = {
      enable = true;

      # Specify the custom minecraft server package
      package = pkgs.fabricServers.fabric-1_21_8.override {
        loaderVersion = "0.17.2";
      }; # Specific fabric loader version

      symlinks = {
        mods = /home/tim/.local/share/PrismLauncher/instances/1.21.8/minecraft/mods;
      };

      properties = {
        server-port = 25566;
        difficulty = 3;
        gamemode = 1;
        max-players = 5;
        motd = "NixOS Minecraft server!";
        white-list = true;
        #enable-rcon = true;
      };

      whitelist = {
        timconspicuous = "4db27365-dbe0-4fd7-a380-10afba6b832c";
        MoinIzzy = "a7d0a634-5cbc-4a9e-a811-7a1bf6d80354";
      };

      ops = {
        timconspicuous = "4db27365-dbe0-4fd7-a380-10afba6b832c";
      };
    };
  };
}

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

    servers.fabric = {
      enable = true;

      # Specify the custom minecraft server package
      package = pkgs.fabricServers.fabric-1_21_8.override {
        loaderVersion = "0.17.2";
      }; # Specific fabric loader version

      symlinks = {
        mods = pkgs.linkFarmFromDrvs "mods" (
          builtins.attrValues {
            FabricAPI = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/jjBL6OsN/fabric-api-0.132.0%2B1.21.8.jar";
              sha512 = "af781f8e06b1fff86c0b7055c9e696552555d5fbc71298447f816689756fe598b2ced182fbf6687c9457472352118e5052fa66de116e7a818584fd8f6e523a7d";
            };
            CCTweaked = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/gu7yAYhd/versions/Xt7jKPpO/cc-tweaked-1.21.8-fabric-1.116.1.jar";
              sha512 = "2f4d57b80ae0710672e0fffaaa204f3369bec1ae38e93d2d1598e3b711fc453b520b555a14d1913272fea9eea7d40b76b4ec319bc006d93c349b0faab91c2404";
            };
          }
        );
      };
      
      jvmOpts = "-Xms2G -Xmx6G -Dfml.readTimeout=180";

      serverProperties = {
        server-port = 25566;
        difficulty = 3;
        gamemode = 0;
        max-players = 5;
        motd = "tim's NixOS server";
        white-list = true;
        #enable-rcon = true;
      };

      whitelist = {
        timconspicuous = "4db27365-dbe0-4fd7-a380-10afba6b832c";
        MoinIzzy = "a7d0a634-5cbc-4a9e-a811-7a1bf6d80354";
      };
    };
  };
}

{ ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Mounting the media storage drive here
  systemd.tmpfiles.rules = [
    "d /srv/media 0755 tim users -"
  ];

  # System identification
  networking.hostName = "nucbox";
  system.stateVersion = "25.05";

  # Bootloader configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Desktop-specific hardware
  services.xserver.xkb = {
    layout = "de";
    variant = "";
  };
  console.keyMap = "de";

  # Enable printing for desktop
  services.printing.enable = true;

  # NFS sharing
  services.nfs.server = {
    enable = true;
    extraNfsdConfig = "--no-nfs-version 3 --no-nfs-version 2";

    exports = ''
      /srv/media/books 192.168.2.0/24(rw,sync,no_subtree_check)
      /srv/media/jellyfin 192.168.2.0/24(rw,sync,no_subtree_check)
    '';
  };
  networking.firewall.allowedTCPPorts = [ 2049 ];

  # Enable Nginx
  services.homelab.nginx = {
    enable = true;
  };

  # Enable Gate
  services.homelab.gate = {
    enable = true;
    domain = "timtinkers.online";
    favicon = ../../modules/proxy/favicon.png;
  };

  # Enable the auth services
  services.homelab.auth = {
    authelia = {
      enable = true;
      domain = "auth.timtinkers.online";
      protectedDomains = [ "calibre.timtinkers.online" ];
    };

    lldap = {
      enable = true;
      baseDn = "dc=timtinkers,dc=online";
      adminUsername = "tim";
    };
  };

  # Enable homepage dashboard
  services.homelab.homepage = {
    enable = true;
    allowedHosts = [
      "localhost:8082"
      "127.0.0.1:8082"
      "home.timtinkers.online"
      "192.168.2.230:8082"
    ];
  };

  # Enable Fabric server
  services.homelab.minecraft = {
    enable = true;

    fabric = {
      enable = true;
      port = 25566;
      enableReverseProxy = true;
      subdomain = "minecraft";

      maxMemory = "6G";
      minMemory = "2G";
      maxPlayers = 5;
      difficulty = 3;
      motd = "tim's NixOS server";

      mods = import ../../modules/minecraft/mods.nix;
      whitelist = import ../../modules/minecraft/whitelist.nix;
      favicon = ../../modules/proxy/favicon.png;
    };
  };

  # Enable homepage dashboard
  services.homelab.calibre = {
    enable = true;
    port = 8880;
    libraries = [ "/srv/media/books/calibre/tim" ];
  };
}

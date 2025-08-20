{ ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # System identification
  networking.hostName = "desktop";
  system.stateVersion = "25.05";

  # Bootloader configuration
  boot.loader = {
    systemd-boot.enable = false;
    efi.canTouchEfiVariables = true;
    grub = {
      enable = true;
      efiSupport = true;
      device = "nodev";
      useOSProber = true;
    };
    grub2-theme = {
      enable = true;
      theme = "tela";
      footer = true;
    };
  };

  # Desktop-specific hardware
  services.xserver.xkb = {
    layout = "de";
    variant = "";
  };
  console.keyMap = "de";

  # Enable printing for desktop
  services.printing.enable = true;

  # Enable the auth services
  services.homelab.auth = {
    enable = true;
    domain = "auth.timtinkers.online";

    # Optional: customize LDAP settings
    lldap.baseDn = "dc=timtinkers,dc=online";
    lldap.adminUsername = "lldap_admin";
  };
}

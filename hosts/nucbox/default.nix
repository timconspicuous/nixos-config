{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
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

  # SSH
  services.openssh.enable = true;

  # Enable the auth services
  services.homelab.auth = {
    enable = true;
    domain = "auth.timtinkers.online";

    # Optional: customize LDAP settings
    lldap.baseDn = "dc=timtinkers,dc=online";
    lldap.adminUsername = "tim";
  };
}

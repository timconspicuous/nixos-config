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
}

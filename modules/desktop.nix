{ config, pkgs, inputs, ... }:

{
  # Desktop environment
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Audio
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Desktop applications
  environment.systemPackages = with pkgs; [
    inputs.zen-browser.packages.x86_64-linux.default

    calibre
    vesktop
    vlc
    whatsie
    yt-dlp

    prismlauncher

    kdePackages.kate
  ];
}

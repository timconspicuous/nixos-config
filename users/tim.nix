{ config, pkgs, ... }:

{
  users.users.tim = {
    isNormalUser = true;
    description = "tim";
    extraGroups = [ "networkmanager" "wheel" ];

    # User-specific packages can go here if needed
    # packages = with pkgs; [ ];
  };

  programs.git = {
    enable = true;
    config = {
      user = {
        name = "timconspicuous";
        email = "git@timtinkers.online";
      };
      init.defaultBranch = "main";
    };
  };
}

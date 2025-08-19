{ inputs, ... }:

{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  users.users.tim = {
    isNormalUser = true;
    description = "tim";
    extraGroups = [
      "networkmanager"
      "wheel"
      "minecraft"
    ];
  };

  programs.git = {
    enable = true;
    config = {
      user = {
        name = "timconspicuous";
        email = "git@timtinkers.online";
      };
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
    };
  };

  # SSH client configuration
  programs.ssh.startAgent = true;
  programs.ssh.extraConfig = ''
    Host tangled.sh
      HostName tangled.sh
      User git
      IdentityFile /home/tim/.ssh/tangled
      IdentitiesOnly yes
  '';

  # SOPS config
  sops.defaultSopsFile = ../secrets/common.yaml;
  sops.defaultSopsFormat = "yaml";
  sops.age.keyFile = "/home/tim/.config/sops/age/keys.txt";

  # Tangled SSH key
  sops.secrets."ssh/tangled" = {
    path = "/home/tim/.ssh/tangled";
    owner = "tim";
    group = "users";
    mode = "0600";
  };
}

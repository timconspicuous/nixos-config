{ config, pkgs, ... }:

{
  users.users.tim = {
    isNormalUser = true;
    description = "tim";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];

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
      push.autoSetupRemote = true;
    };
  };

  # Enable SSH agent system-wide
  programs.ssh.startAgent = true;

  # SSH client configuration
  programs.ssh.extraConfig = ''
    Host tangled.sh
      HostName tangled.sh
      User git
      IdentityFile /home/tim/.ssh/id_ed25519
      IdentitiesOnly yes
  '';

  # Create the SSH directory and set up keys on system activation
  system.activationScripts.setupSSHKeys = {
    text = ''
      # Create SSH directory for tim
      mkdir -p /home/tim/.ssh
      chmod 700 /home/tim/.ssh
      chown tim:users /home/tim/.ssh

      # Copy SSH keys if they exist in the config directory
      CONFIG_DIR="${config.users.users.tim.home or "/home/tim"}/nixos-config"

      if [ -f "$CONFIG_DIR/secrets/ssh_keys/id_ed25519" ]; then
        cp "$CONFIG_DIR/secrets/ssh_keys/id_ed25519" /home/tim/.ssh/id_ed25519
        chmod 600 /home/tim/.ssh/id_ed25519
        chown tim:users /home/tim/.ssh/id_ed25519
        echo "SSH private key copied"
      else
        echo "SSH private key not found at $CONFIG_DIR/secrets/ssh_keys/id_ed25519"
      fi

      if [ -f "$CONFIG_DIR/secrets/ssh_keys/id_ed25519.pub" ]; then
        cp "$CONFIG_DIR/secrets/ssh_keys/id_ed25519.pub" /home/tim/.ssh/id_ed25519.pub
        chmod 644 /home/tim/.ssh/id_ed25519.pub
        chown tim:users /home/tim/.ssh/id_ed25519.pub
        echo "SSH public key copied"
      else
        echo "SSH public key not found at $CONFIG_DIR/secrets/ssh_keys/id_ed25519.pub"
      fi
    '';
    deps = [ ];
  };
}

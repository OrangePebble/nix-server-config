{
  inputs,
  config,
  vars,
  ...
}:
{
  networking.hostName = vars.hostname;
  # Obtained via `head -c 8 /etc/machine-id`, might require manually mounting
  #  /home on first boot.
  networking.hostId = "59718dc4";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.pebble = {
    isNormalUser = true;
    description = vars.fullname;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    hashedPasswordFile = config.secrets.password.path;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOIZeqsx4YGlynKAgAW/kFvcdb3Ec4ES+b+j8eZuQ6l2 pebble@orange"
    ];
  };
  secrets.password = {
    sopsFile = "${vars.secretsDirectory}/password";
    format = "binary";
    # Entire file.
    key = "";
    # Only the user can read and nothing else.
    mode = "0400";
    owner = vars.username;
    neededForUsers = true;
  };
  secrets.smtp-password = {
    sopsFile = "${vars.secretsDirectory}/smtp-password";
    format = "binary";
    # Entire file.
    key = "";
    # Only the user can read and nothing else.
    mode = "0400";
    owner = vars.username;
  };

  # https://wiki.nixos.org/wiki/ZFS#Mail_notifications_(ZFS_Event_Daemon)
  # https://wiki.archlinux.org/title/Msmtp
  # https://gist.github.com/nfsarmento/4bb5e0ff3090f150c6696793cf8e8488
  programs.msmtp = {
    enable = true;
    setSendmail = true;
    defaults = {
      aliases = "/etc/aliases";
      auth = true;
      tls = "on";
      tls_certcheck = "off";
    };
    accounts = {
      default = {
        host = "smtp.gmail.com";
        port = 587;
        from = "orangepebbleauth@gmail.com";
        user = "orangepebbleauth@gmail.com";
        passwordeval = "cat ${config.secrets.smtp-password.path}";
      };
    };
  };
  environment.etc.aliases.text = ''
    root: orangepebblecreations@gmail.com
  '';
  services.zfs.zed = {
    enableMail = true;
    settings = {
      ZED_EMAIL_ADDR = [ "root" ];
      # send notification if scrub succeeds
      ZED_NOTIFY_VERBOSE = true;
    };
  };
  # for zed enableMail, enable sendmailSetuidWrapper
  services.mail.sendmailSetuidWrapper.enable = true;

  security.sudo.extraConfig = ''
    Defaults pwfeedback # Shows asterisks when typing password.
  '';

  # Sets the configuration revision string to either the git commit reference or 'dirty'.
  # Can be seen on entries shown by 'nixos-rebuild list-generations'.
  system.configurationRevision = inputs.self.rev or "dirty";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nix.optimise = {
    # Cleans the store
    automatic = true;
    dates = [ "weekly" ];
  };
  nix.gc = {
    # Deletes old generations
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Adds current flake to the registry so it can be accessed in things like the repl.
  nix.registry.config.flake = inputs.self;

  services.openssh = {
    enable = true;
    ports = [ 22 ];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      TCPKeepAlive = "yes";
      AllowUsers = [ "pebble" ];
    };
  };
  services.fail2ban.enable = true;

  networking.interfaces.enp9s0.wakeOnLan.enable = true;

  secrets.wifi = {
    sopsFile = "${vars.secretsDirectory}/wifi";
    format = "binary";
    # Entire file.
    key = "";
    # Everyone can read.
    mode = "0444";
    owner = vars.username;
  };
  networking.wireless = {
    enable = true;
    secretsFile = config.sops.secrets.wifi.path;
    networks."NOS-2FD0 2.4GHz".pskRaw = "ext:psk_home";
  };

  services.tailscale = {
    enable = true;
    extraSetFlags = [
      "--advertise-exit-node"
      "--advertise-routes=192.168.1.0/24"
    ];
  };
  # Makes the server work lik a subnet router.
  # Required to be a tailscale exit node.
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;

  system.stateVersion = vars.stateVersion;
}

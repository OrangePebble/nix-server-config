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
  networking.wireless = {
    enable = true;
    secretsFile = config.sops.secrets.wifi.path;
    networks."NOS-2FD0 2.4GHz".pskRaw = "ext:psk_home";
  };
  secrets.wifi = {
    sopsFile = ../secrets/wifi;
    format = "binary";
    # Entire file.
    key = "";
    # Everyone can read.
    mode = "0444";
    owner = vars.username;
  };

  # https://wiki.nixos.org/w/index.php?title=Internet_Connection_Sharing
  # Set a static IP on the "downstream" interface
  networking.interfaces."enp9s0" = {
    useDHCP = false;
    ipv4.addresses = [
      {
        address = "10.0.0.1";
        prefixLength = 24;
      }
    ];
  };
  networking.firewall.extraCommands = ''
    # Set up SNAT on packets going from downstream to the wider internet
    iptables -t nat -A POSTROUTING -o wlp12s0f3u4 -j MASQUERADE

    # Accept all connections from downstream. May not be necessary
    iptables -A INPUT -i enp9s0 -j ACCEPT
  '';
  # Run a DHCP server on the downstream interface
  services.kea.dhcp4 = {
    enable = true;
    settings = {
      interfaces-config = {
        interfaces = [
          "enp9s0"
        ];
      };
      lease-database = {
        name = "/var/lib/kea/dhcp4.leases";
        persist = true;
        type = "memfile";
      };
      rebind-timer = 2000;
      renew-timer = 1000;
      subnet4 = [
        {
          id = 1;
          pools = [
            {
              pool = "10.0.0.2 - 10.0.0.255";
            }
          ];
          subnet = "10.0.0.1/24";
        }
      ];
      valid-lifetime = 4000;
      option-data = [
        {
          name = "routers";
          data = "10.0.0.1";
        }
      ];
    };
  };
  # Kea, the DHCP server I'm using to share internet, cannot open its DHCP socket until a downstream device gives enp9s0 carrier.
  # This service gets the carrier value every 2 seconds and restarts Kea if it turns to 1 (UP).
  # There is a simpler and cleaner way to do this with udev rules but my internet card doesn't seem to emit the required change event.
  systemd.services.kea-dhcp4-carrier-watcher = {
    description = "Restart Kea DHCP4 when enp9s0 gains carrier";
    wantedBy = [ "multi-user.target" ];
    after = [ "kea-dhcp4-server.service" ];
    serviceConfig = {
      Restart = "always";
      RestartSec = 5;
    };
    script = ''
      carrier=0
      while true; do
        next_carrier=$(< /sys/class/net/enp9s0/carrier)
        if [ "$carrier" = 0 ] && [ "$next_carrier" = 1 ]; then
          ${config.systemd.package}/bin/systemctl restart kea-dhcp4-server.service
        fi
        carrier=$next_carrier
        sleep 2
      done
    '';
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.pebble = {
    isNormalUser = true;
    description = "OrangePebble";
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    hashedPasswordFile = config.secrets.password.path;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOIZeqsx4YGlynKAgAW/kFvcdb3Ec4ES+b+j8eZuQ6l2 pebble@orange"
    ];
  };
  secrets.password = {
    sopsFile = ../secrets/password;
    format = "binary";
    # Entire file.
    key = "";
    # Only the user can read and nothing else.
    mode = "0400";
    owner = vars.username;
    neededForUsers = true;
  };
  secrets.smtp-password = {
    sopsFile = ../secrets/smtp-password;
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

  # I need to persist this directory across reboots.
  fileSystems."/etc/ssh" = {
    device = "/persist/etc/ssh";
    fsType = "none";
    options = [ "bind" ];
    # Don't check this "file system" for integrity.
    noCheck = true;
  };
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

  # https://github.com/tailscale/tailscale/issues/3039#issuecomment-1049084065
  # I need to persist this directory across reboots.
  fileSystems."/var/lib/tailscale" = {
    device = "/persist/var/lib/tailscale";
    fsType = "none";
    options = [ "bind" ];
    # Don't check this "file system" for integrity.
    noCheck = true;
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

  # Persist which users have sudoed so I don't get the first time message every time.
  fileSystems."/var/db/sudo/lectured" = {
    device = "/persist/var/db/sudo/lectured";
    fsType = "none";
    options = [ "bind" ];
    # Don't check this "file system" for integrity.
    noCheck = true;
  };

  system.stateVersion = "24.05";
}

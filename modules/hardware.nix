{
  config,
  lib,
  pkgs,
  modulesPath,
  vars,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot = {
    initrd.availableKernelModules = [
      "nvme"
      "xhci_pci"
      "ahci"
      "usb_storage"
      "usbhid"
      "sd_mod"
    ];
    initrd.kernelModules = [ ];
    kernelModules = [ "kvm-amd" ];
    extraModulePackages = [ ];
    loader.grub = {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true;
      device = "nodev";
      zfsSupport = true;
    };
  };
  environment.systemPackages = with pkgs; [
    grub2 # Makes grub commands available in the terminal.
  ];

  time.timeZone = "Europe/Lisbon";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_IE.UTF-8";
    LC_IDENTIFICATION = "en_IE.UTF-8";
    LC_MEASUREMENT = "en_IE.UTF-8";
    LC_MONETARY = "en_IE.UTF-8";
    LC_NAME = "en_IE.UTF-8";
    LC_NUMERIC = "en_IE.UTF-8";
    LC_PAPER = "en_IE.UTF-8";
    LC_TELEPHONE = "en_IE.UTF-8";
    LC_TIME = "en_IE.UTF-8";
  };

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp14s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp15s0.useDHCP = lib.mkDefault true;

  networking.networkmanager.enable = true;
  # This makes the system wait for the network before booting. This also fails rebuild if enabled.
  systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;

  # I could've let disko configure everything, besides /home
  #  (because I have make zfs not mount it, as systemd also
  #  tries to mount it for some reason and causes problems)
  #  including swap, but this is pretty simple, and I don't
  #  really know how disko would work with future disk additions.
  fileSystems = {
    "/home" = {
      device = "zdata/home";
      fsType = "zfs";
      # Makes /home be mounted during stage1 of the boot process, which is required
      #  for things like sops-nix being able to get the age keys during boot.
      neededForBoot = true;
    };
    # For impermanence.
    "/persist" = {
      device = "zroot/persist";
      fsType = "zfs";
      options = [ "zfsutil" ];
      # The impermanence guide said this was needed.
      neededForBoot = true;
    };
    "/" = {
      device = "zroot/root";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };
    "/nix" = {
      device = "zroot/nix";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };
    "/boot" = {
      device = "/dev/disk/by-id/nvme-Lexar_SSD_NM620_256GB_QAG282R016101P1157-part1";
      fsType = "vfat";
    };
  };
  swapDevices = [
    {
      device = "/dev/disk/by-id/nvme-Lexar_SSD_NM620_256GB_QAG282R016101P1157-part2";
    }
  ];

  # https://gist.github.com/lesserfish/8c0cfc6bb07c17c5af8a3759d2eb9e9a
  # https://discourse.nixos.org/t/systemd-stage-1-migration/77113/7
  # This rollbacks / on every boot to cause impermanence.
  # Sub-directories like '/home' defined above aren't affected by this.
  boot.initrd.systemd.services.zfs-impermanence-rollback = {
    wantedBy = [ "initrd.target" ];
    # Dynamically generated service based on the zpool name ("zroot").
    after = [ "zfs-import-zroot.service" ];
    before = [ "sysroot.mount" ];
    path = [ pkgs.zfs ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      zfs rollback -r zroot/root@blank
    '';
  };

  services.zfs.autoScrub.enable = true;
  services.zfs.autoSnapshot = {
    enable = true;
    flags = "-k -p --utc";
  };

  nixpkgs.hostPlatform = lib.mkDefault vars.hostPlatform;
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}

{
  vars,
  ...
}:
{
  # Non-"home manager" syncthing fails to create '/var/lib/syncthing'.
  # I need to persist this directory across reboots.
  fileSystems."/var/lib/syncthing" = {
    device = "/persist/var/lib/syncthing";
    fsType = "none";
    options = [ "bind" ];
    # Don't check this "file system" for integrity.
    noCheck = true;
  };
  systemd.tmpfiles.rules = [
    "Z /var/lib/syncthing 755 ${vars.username} users - -"
  ];
  services.syncthing = {
    # WARNING: If something is wrong, syncthing will just not have any
    #  devices or folders.
    # INFO: Versioning cleanup interval uses a different method which
    #  nixpkgs doesn't seem to support.
    enable = true;
    user = vars.username;
    group = "users";
    openDefaultPorts = true;
    settings = {
      devices = {
        "phone".id = "R2RNYGN-BZPUWLZ-6OEOT77-ALGBSJP-MD2JPBY-AOY2T72-UX25SEB-H47LVAO";
        "tablet".id = "XR6AZSI-APGKKIB-LWMMCKW-6E63TBX-KFBSLVG-7JYURKQ-TZNGESZ-IVNNDQ5";
        "desktop".id = "PFHNH6B-ZKMGLU4-BK2RU52-RIKVISP-EXI5N6U-4SLLJU2-D4Q2NPF-LXSDMAC";
      };
      folders = {
        "default" = {
          id = "default";
          path = "~/sync/default";
          devices = [
            "phone"
            "tablet"
            "desktop"
          ];
          versioning = {
            type = "staggered";
            params = {
              #cleanInterval = "604800"; # clean once per week
              maxAge = "0"; # 1 year
            };
          };
        };
        "obsidian-vaults" = {
          id = "obsidian-vaults";
          path = "~/sync/obsidian-vaults";
          devices = [
            "phone"
            "tablet"
            "desktop"
          ];
          versioning = {
            type = "staggered";
            #cleanupIntervalS = "604800"; # clean once per week
            params.maxAge = "0"; # forever
          };
        };
        "music" = {
          id = "music";
          path = "~/public/music/personal";
          devices = [
            "desktop"
          ];
        };
        "tachiyomi-backup" = {
          id = "tachiyomi-backup";
          path = "~/sync/tachiyomi-backup";
          devices = [
            "phone"
            "tablet"
            "desktop"
          ];
        };
        "WIT" = {
          id = "wit";
          path = "~/sync/WIT";
          devices = [
            "phone"
            "desktop"
          ];
        };
      };
    };
  };
}

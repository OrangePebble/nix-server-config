{ pkgs, ... }:
{
  nixpkgs.config = {
    # Allow unfree packages
    allowUnfree = true;
    # Workaround for https://github.com/nix-community/home-manager/issues/2942
    allowUnfreePredicate = _: true;
  };

  programs =
    let
      # https://nixos.wiki/wiki/Games
      # https://discourse.nixos.org/t/programs-nix-ld-libraries-expects-set-instead-of-list/56009/4
      # https://wiki.nixos.org/wiki/FAQ#I've_downloaded_a_binary%2C_but_I_can't_run_it%2C_what_can_I_do%3F
      # Should make most binaries and appimages run.
      additional_libraries =
        pkgs.steam-run.args.multiPkgs pkgs
        ++ (with pkgs; [
          # Add any missing dynamic libraries for unpackaged binaries/appimages here, NOT in environment.systemPackages
          libusb1 # Wraith Master
          webkitgtk_4_1 # OrcaSlicer
        ]);
    in
    {
      # So that regular binaries can be run.
      # This doesn't export to LD_LIBRARY_PATH in order to not affect packages that
      #  are correctly defined.
      # Run "export LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH" if required.
      nix-ld = {
        enable = true;
        libraries = additional_libraries;
      };
    };

  environment.systemPackages = with pkgs; [
    unrar
    p7zip
  ];
}

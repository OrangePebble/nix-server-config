# This file sets up 'sops' so that I'm able to commit and use encrypted secrets.
# I can't get the secrets during evaluation (so I'm not able to directly add them
#  to option), because then the secrets would be plain text in the store.
#  It's a bit hard to figure out why thats a bad idea, but here is what I got.
#  The nix store is world-readable, which means everyone with access to your
#  system can read it, be it other users or malicious attackers that were able to
#  get any remote access to your server.
#  Additionally, if you want to build a configuration then send it to another
#  machine, the build machine will have a copy of the secrets in their store.
#  I don't think this are important usecases for me, but I should probably
#  follow good convention, just in case.
# If I do want to try and use secrets during evaluation time, this issue seems
#  to have a decent solution using 'nix plugins':
#  https://github.com/Mic92/sops-nix/issues/624
# I'm using sops with 'age', and while I technically could use ssh keys for this,
#  that would require my ssh keys not having a passphrase, so thats a no go.
#
# As age only has to be set up once and it would be complicated to do it
#  automatically with SSH passphrases, I do it manually.
# To do this first create a temporary copy of the private SSH key file:
#  `cp ~/.ssh/<file> /tmp/<file>`
# Then transform the the copy into a version without a passphrase:
#  `ssh-keygen -p -N "" -f /tmp/<file>`
# Then generate the age key:
#  `ssh-to-age -private-key -i /tmp/<file> > ~/.config/sops/age/keys.txt`
# And finally don't forget to delete the copy of the SSH key file:
#  `rm /tmp/<file>`
#
# To generate a public age key (to be added to '.sops.yaml'), run the following
#  with a target machine's public SSH key file:
#  `cat <filename>.pub | ssh-to-age'
#  Or the following:
#  `ssh-keyscan <target-hostname> | ssh-to-age'
{
  config,
  inputs,
  pkgs,
  lib,
  vars,
  ...
}:
{
  imports = [
    inputs.sops-nix.nixosModules.sops
    (lib.mkAliasOptionModule [ "secrets" ] [ "sops" "secrets" ])
  ];

  environment.systemPackages = with pkgs; [
    sops
    age
    ssh-to-age
  ];

  # To create an encrypted file from scratch and edit encrypted files run: `sops <file>`.
  # To encrypt an existing file run: `sops encrypt -i <file>`.
  # To decrypt a file run: `sops decrypt -i <file>`.
  # The default key sops tries to get is the file name.
  sops = {
    age.keyFile = "${config.users.users.${vars.username}.home}/.config/sops/age/keys.txt";

    # Not automatically adding secrets because I don't see the point yet, but
    #  leaving this here.
    #
    # Inspired by https://github.com/ncfavier/config/blob/main/modules/secrets.nix
    #  but because I want more control over non-binary secrets, I've only "automated" binary secrets.
    # secrets = with lib; let
    #   secretsDir = "${inputs.self}/secrets";
    # in
    #   mapAttrs' (
    #     name: _:
    #       nameValuePair name {
    #         sopsFile = "${secretsDir}/${name}";
    #         format = "binary";
    #       }
    #   ) (filterAttrs (
    #       name: _:
    #         length (splitString "." name) == 1
    #     )
    #     (builtins.readDir secretsDir));
  };
}

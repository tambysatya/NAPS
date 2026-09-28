{flakeRoot, inputs, lib, naps, pkgs, path, ...}:

let

    gen = import ./lib {inherit flakeRoot inputs lib pkgs naps path;};

    in
{
    generator = pkgs.writeShellApplication {
            name = "gen-secrets";
            runtimeInputs = [
                pkgs.age
                pkgs.openssl
                pkgs.openldap
                pkgs.sops
                pkgs.step-cli
                pkgs.gzip
            ];
            text = naps.assets.generator;
           };
    mkInstaller = vmname: pkgs.writeShellApplication {
            name = "install-secrets";
            text = naps.assets.install.${vmname};
            runtimeInputs = [
                pkgs.age
                pkgs.openssh
            ];
           };
}

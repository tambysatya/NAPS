{flakeRoot, inputs, lib, infra, pkgs, path, ...}:

let

    gen = import ./lib {inherit flakeRoot inputs lib pkgs infra path;};

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
            text = gen.processSecrets;
           };
    mkInstaller = vmsecrets: pkgs.writeShellApplication {
            name = "install-secrets";
            text = gen.mkInstaller vmsecrets;
            runtimeInputs = [
                pkgs.age
                pkgs.openssh
            ];
           };
}

{inputs, lib, pkgs, naps, registry, vmname, ...}:
let
    dependencies = import ./naps-dependencies.nix {inherit inputs lib pkgs naps;};
    security = import ./security.nix {inherit inputs lib naps vmname;};
    volumes = import ./volumes.nix {inherit inputs lib pkgs naps registry;};
in
{
    inherit (dependencies) mkDBDependencies;
    inherit (security) generateSecret generateCertificate generateReverseProxy;
    inherit (volumes) compileVolumes;
}

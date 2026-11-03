{flakeRoot, lib, inputs, pkgs, config, path, ...}:
let
    utils = import "${flakeRoot}/lib" {inherit inputs lib flakeRoot;};
    systemPackages = [pkgs.nix-index
                      pkgs.vim pkgs.git
                      pkgs.htop pkgs.wget
                      pkgs.molly-guard
                      pkgs.rxvt-unicode];
    defaultVMConf = 
        vmname: _:
        {
            ${vmname}.config = {
                system.stateVersion = "26.05";
                boot.kernelParams = ["console=tty1" "console=ttyS0,115200"];
                boot.loader.systemd-boot.enable = true;
                boot.loader.efi.canTouchEfiVariables = true;
                time.timeZone = "Europe/Paris";
                i18n.defaultLocale = "fr_FR.UTF-8";
                nix.settings.experimental-features = ["nix-command" "flakes"]; #enable flakes
                security.pki.certificateFiles = [
                    "${path}/.secrets/git/root_ca.crt"
                    "${path}/.secrets/git/intermediate_ca.crt"
                ]; #trust the root-ca
                environment.etc."root_ca.crt".text = builtins.readFile "${path}/.secrets/git/root_ca.crt";
                environment.etc."intermediate_ca.crt".text = builtins.readFile "${path}/.secrets/git/intermediate_ca.crt";
                programs.vim = {
                    enable = true;
                    defaultEditor = true;
                };
                environment.systemPackages = systemPackages;
            };
        };
    defaultContainerConf =
        ctname: ctenv:
        {
            ${utils.envHostUID ctenv}.config.containers.${ctname} = {
                autoStart = true;
                specialArgs = {
                    inherit flakeRoot; 
                    inherit (config) naps;
                };
                config = {
                    security.pki.certificateFiles = [
                        "${path}/.secrets/git/root_ca.crt"
                        "${path}/.secrets/git/intermediate_ca.crt"
                    ]; #trust the root-ca
                    environment.etc."root_ca.crt".text = builtins.readFile "${path}/.secrets/git/root_ca.crt";
                    environment.etc."intermediate_ca.crt".text = builtins.readFile "${path}/.secrets/git/intermediate_ca.crt";
                    environment.systemPackages = systemPackages;
                    system.stateVersion = "26.05";
                    nix.settings.experimental-features = ["nix-command" "flakes"]; #enable flakes
                };
            };
        };



in {
    naps.outputs.systems = 
        lib.mkMerge 
            (lib.mapAttrsToList defaultVMConf config.naps.internal.envs.vms ++
            lib.mapAttrsToList defaultContainerConf config.naps.internal.envs.vms);
}



{flakeRoot, lib, inputs, pkgs, config, path, ...}:

let

    utils = import ./lib {inherit inputs lib flakeRoot;};
    systemPackages = [pkgs.nix-index
                      pkgs.vim pkgs.git
                      pkgs.htop pkgs.wget
                      pkgs.molly-guard
                      pkgs.rxvt-unicode];

    defaultConf = 
        vmname: _:
        {
            config = {


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


                  services.openssh.enable = true;
                  networking.firewall = { #TODO
                    allowedTCPPorts = [22]; # ++ generateTCPPorts vmconf.services 
                    allowedUDPPorts = []; # ++ generateUDPPorts vmconf.services
                  };
                  environment.systemPackages = systemPackages;

                  containers = 
                    utils.mergeAll 
                        (lib.map 
                            (srvuid: {
                                ${srvuid} = {
                                    autoStart = true;
                                    specialArgs = {inherit flakeRoot path;};
                                    config = config.infra.outputs.systems.${srvuid}.config // {
                                                    imports = ["${flakeRoot}/services/step-renew"];
                                                    environment.systemPackages = systemPackages;
                                                 };
                                };
                             })
                         config.infra.topology.vms.${vmname}.containers);
            };  
        };



in

{
    imports = [./options
               ./systems
               ./domains
               ./iso.nix
              ];
    #infra.outputs = utils.mergeAll (lib.mapAttrsToList processSystem config.infra.deploy.systems);
    infra.outputs.systems = lib.mapAttrs defaultConf config.infra.topology.vms;
}

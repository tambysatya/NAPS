{lib, inputs, flakeRoot, pkgs , config, path, ...}:

let
    utils = import ./lib {inherit lib inputs;};
    mkUser = {name, uid}:
        {
            users.${name} = {
               inherit uid;
               group = name;
               isSystemUser = true;
            };
            groups.${name} = {
                gid = uid;
            };
        };

in {

    infra.outputs.iso = {
        boot.kernelParams = ["console=tty1" "console=ttyS0,115200"];
        nix.settings.experimental-features = ["nix-command" "flakes"]; #enable flakes
        environment.systemPackages = [pkgs.dmidecode 
                                      inputs.disko.packages.${pkgs.system}.disko];


        networking.hostName = "bootstrap-vm";
        environment.etc."nixos".source = builtins.path {
                            name = "deploy-flake";
                            path = path;
                        };
        };
        #users = utils.mergeAll (map mkUser config.infra.deploy.users);

}

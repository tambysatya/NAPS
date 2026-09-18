{lib, inputs, flakeRoot, pkgs, config, path, ...}:

let
    utils = import ./lib {inherit lib inputs flakeRoot;};
    mkUser = name: {service, uid}:
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

    provisionersAddrs = lib.unique (map (builtins.getAttr "provisionerAddr") (builtins.attrValues config.naps.topology.vms));
in {

    naps.outputs.iso = {
        boot.kernelParams = [
            #"console=tty1"
            "console=ttyS0,115200"
        ];
        system.stateVersion = "26.05";
        nix.settings.experimental-features = ["nix-command" "flakes"]; #enable flakes
        environment.systemPackages = [pkgs.dmidecode 
                                      inputs.disko.packages.${pkgs.system}.disko];


        networking.hostName = "bootstrap-vm";
        networking.interfaces.enp1s0.useDHCP = false;
        networking.nameservers = config.naps.topology.dns;
        environment.etc."nixos".source = builtins.path {
                            name = "deploy-flake";
                            path = path;
        };
        users = utils.mergeAll (lib.mapAttrsToList mkUser config.naps.deploy.users);

        networking.hosts = {"127.0.0.1" = ["${config.naps.topology.provisionerHost}"];};
        services.haproxy = {
            enable = true;
            config = ''
                defaults
                    timeout connect 5s
                    # connections are handled by the kernels
                    timeout client 30s
                    timeout server 30s
                frontend fe_provisioner
                    bind :8080
                    mode tcp
                    use_backend be_provisioner

                backend be_provisioner
                    mode tcp
                    ${lib.concatStringsSep "\n" 
                        (lib.imap
                         (i: ip:
                          "     server provisioner_${lib.toString i} ${ip}:8080 check ${if i ==1 then "" else "backup"}")
                         provisionersAddrs)}

            '';
        };


    };
}

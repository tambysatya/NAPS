{lib, config, inputs,pkgs, naps, registry, vmname, vmconf, ...}:

/* Deployement of services behind a container */



let

    vars = import "${inputs.self.outPath}/lib/vars.nix" {inherit lib naps registry inputs pkgs;};
    comp = import "${inputs.self.outPath}/lib/compiler" {inherit lib inputs pkgs registry naps vmname;};

    initialize-host = {
          networking.nat = {
            enable = true;
            internalInterfaces = ["ve-+"];
            externalInterface = "enp1s0";
            enableIPv6 = true;
      };
    };

    # creates an entry of containers= on the host
    mkContainer = {servicename, host-addr, local-addr}:  
        {
           networking.interfaces."ve-${servicename}" = { #Manually config the interface of the host
                ipv4.addresses = [
                    {address = host-addr; prefixLength=24;}
                ];
           };
           containers."${servicename}" = 
               let ct-name = vars.container_id vmname servicename;
                   ct-conf = {
                        inherit (vmconf) host vcpu memory;
                        services = [servicename];
                        containers = [];
                   };
                   ct-registry = registry // {vms.${ct-name} = {attachedVolumes = {}; persistentDirectories = {};}; };
               in {
                    specialArgs = {inherit inputs naps; registry=ct-registry; vmname=ct-name; vmconf=ct-conf;}; #TODO
                    autoStart = true;
                    privateNetwork = true;
                    hostAddress = host-addr;
                    #localAddress = local-addr;


                    bindMounts= {
                        "/var/lib/sops-nix/key.txt" = { #mounting the age key of the volume
                            hostPath = "/run/secrets/${ct-name}.key";
                            isReadOnly = true;
                        };
                        "/etc/resolv.conf" = {
                            hostPath = "/etc/resolv.conf";
                            isReadOnly = true;
                        };
                    };
                    config = {...}:{
                        compiler.options = {
                            noEndpoints = true; #do not process endpoints
                            noMounts = true;
                        };
                        imports = [
                            
                            "${inputs.self.outPath}/services/${servicename}"

                            "${inputs.self.outPath}/services/step-renew"
                            "${inputs.self.outPath}/profiles/base.nix"
                            "${inputs.self.outPath}/modules/registry"

                            "${inputs.self.outPath}/modules/compiler"

                            #"${inputs.self.outPath}/modules/compiler/options.nix"
                            #"${inputs.self.outPath}/modules/compiler/base.nix"
                            #"${inputs.self.outPath}/modules/compiler/native.nix"
                            inputs.sops-nix.nixosModules.sops
                            
                        ]; 

                        time.timeZone = "Europe/Paris";
                        i18n.defaultLocale = "fr_FR.UTF-8";

                        networking = {
                            hostName = ct-name;
                            useHostResolvConf = lib.mkForce false;
                            #services.resolved.enable = false;
                            nameservers= naps.dns;

                            # Manually config the interface of the container
                            defaultGateway = host-addr;
                            interfaces.eth0.ipv4.addresses = [
                                { address = local-addr; prefixLength  = 24; }
                            ];
                        };



                    };

           };
           systemd.services."container@${servicename}" = {
                serviceConfig.TimeoutStartSec = lib.mkForce "5min"; #To avoid premature halting if the naps-deps are not satisfied immediately
           };
        };

in{ 

config = lib.mkIf (vmconf.containers != []) 
            (lib.mkMerge [
                (initialize-host)
                (lib.mkMerge 
                        (lib.imap
                            (i: servicename: 
                                let local-addr = "192.168.100.${lib.toString (50+i)}";
                                    container_id = vars.container_id vmname servicename;
                                in lib.mkMerge [
                                    (mkContainer {inherit servicename local-addr; host-addr= "192.168.100.1";})
                                    (comp.generateSecret 
                                            {names = ["${container_id}.key"]; reload = ["container@ct-${servicename}.service"];})
                                    (lib.mkIf (lib.hasAttr servicename registry.services)
                                        (lib.mkMerge 
                                            (lib.map 
                                                (ep: if ep.is_http then
                                                        comp.generateReverseProxy {
                                                            fronthost = ep.host;
                                                            backhost = "http://${local-addr}";
                                                            inherit (ep) extraNginxConfig;}
                                                     else
                                                        {})
                                                registry.services.${servicename}.endpoints)))
                                ])
                            vmconf.containers))

                # Containers requesting a DBAccess cannot be launched before postgres is reachable
                (comp.mkDBDependencies 
                    (lib.map 
                        (servicename: "container@${servicename}.service")
                        (lib.filter 
                            (servicename: builtins.hasAttr servicename registry.services &&
                                          (registry.services."${servicename}".dbAccesses != [])) 
                            vmconf.containers)))
            ]);

}

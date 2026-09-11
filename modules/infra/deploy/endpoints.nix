{flakeRoot, lib, inputs, config, ...}:

let
    utils = import ./lib.nix {inherit lib inputs flakeRoot;};




    processVM = # For each VM, all the endpoints are registered
        vmname: utils.mergeAll (lib.mapAttrsToList (processService vmname) config.infra.services);

    processService = 
        vmname: srvname: {deployements, endpoints,...}:
        let tcp = map (processEndpoint vmname "tcp" deployements) endpoints.tcp;
            udp = map (processEndpoint vmname "udp" deployements) endpoints.udp;
            http = map (processEndpoint vmname "http" deployements) endpoints.http;
        in utils.mergeAll (tcp ++ udp ++ http);

    processEndpoint= 
        vmname: mode: deployements: endpoint:
        let isHostedNatively = builtins.elem vmname (map utils.envUID (builtins.attrValues deployements)); # true if the vm runs the service natively
        in if mode != "http" && ! isHostedNatively # creates the L4 proxy only if the VM does not host the service natively, to avoid raising an Address already in use error.
        then utils.mergeAll (map (processL4Endpoint mode vmname endpoint) (builtins.attrValues deployements))
        else if mode == "http" # even if the service runs natively, registering an HTTP endpoint implies registering the Vhost in haproxy
        then utils.mergeAll (map (processHTTPEndpoint vmname endpoint) (builtins.attrValues deployements))
        else {};



    processL4Endpoint =
        mode: vmname: endpoint: env:
        let isLocal = utils.envHost env == vmname; #true if the endpoint is located within a container on the VM (services running natively on the VM have been previously filtered)
            #backendIP = if isLocal then utils.envIP config env else utils.envHostIP config env; # the backend ip of the service points either to the container or to the host
            backendIP = if ! isLocal then utils.envHostIP config env # the backend ip of the service points either to the container or to the host
                        else if utils.envUID env == vmname then "127.0.0.1"
                        else utils.envIP config env;
        in {
           proxy.${mode}.${lib.toString endpoint.port} = {
                    frontend = {
                        public = isLocal; # gives access to everyone if the service is hosted locally 
                        inherit (endpoint) hostname;
                    };
                    backends = [{
                        inherit env;  
                        ip = backendIP;
                        inherit (endpoint) port;
                    }];
                    inherit (endpoint) extraConfig;
            };
        };
    processHTTPEndpoint =
        vmname: endpoint: env:
        let isLocal = utils.envHost env == vmname; 
            #backendIP = if isLocal then utils.envIP config env else utils.envHostIP config env; # the backend ip of the service points either to the container or to the host
            backendIP = if ! isLocal then utils.envHostIP config env # the backend ip of the service points either to the container or to the host
                        else if utils.envUID env == vmname then "127.0.0.1"
                        else utils.envIP config env;
        in {
            proxy.http.${endpoint.hostname} = {
                inherit (endpoint) extraConfig;
                tls = if isLocal then endpoint.tls else false; # never terminates tls if the service is not hosted locally.
                public = isLocal;
                backends = [{
                    inherit env;
                    ip = backendIP;
                    port = if isLocal then endpoint.port else 443;
                }];
            };
        };


in {
    config.infra.deploy.systems = lib.mapAttrs (name: _: processVM name) (config.infra.topology.vms);
}

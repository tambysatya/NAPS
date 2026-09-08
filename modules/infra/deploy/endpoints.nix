{flakeRoot, lib, inputs, config, ...}:

let
    utils = import ./lib.nix {inherit lib inputs flakeRoot;};


    mkHTTPProxy = 
    env:
    {hostname, port, tls, extraConfig,...}:
    let cert = {inherit hostname; owner="haproxy"; reload=["haproxy.service"];};
    in {
        ${utils.envHost env} = {
            proxy.http.${hostname} = {
                inherit tls extraConfig;
                backends = [
                    {
                        ip = if env.type == "container"
                             then utils.envIP config env
                             else "localhost";
                        inherit port env;
                    }
                ];
            };
            secrets = if tls then utils.certToSecret cert else [];
            sslCertificates = if tls then [cert] else [];
        };
    };

    mkTCPProxy = 
    env:
    {hostname, port, extraConfig,...}:
    if (env.type == "container") then
        {
            ${utils.envHost env}.proxy.tcp.${hostname} = {
                frontend = {ip = "0.0.0.0"; inherit port;};
                backends = [
                    {ip = utils.envIP config env; inherit port env;}
                ];
                inherit extraConfig;
            };
        }
    else {};





    processUDP = throw "UDP not implemented yet";
    processService = 
        srv@{deployements, endpoints,...}:
        let allenvs = builtins.attrValues deployements;
            ctenvs = lib.filter (env: env.type == "container") allenvs; #TCP/UDP proxy are deployed only when the service runs within a container
            allTCP =
                lib.concatMap
                    (env: map (mkTCPProxy env) endpoints.tcp)
                    ctenvs; 
            allUDP =
                lib.concatMap
                    (env: map (processUDP env) endpoints.udp)
                    ctenvs;
            allHTTP = lib.concatMap
                        (env: map (mkHTTPProxy env) endpoints.http)
                        allenvs; #we build a reverse proxy for all http endpoints (otherwise they should be declared TCP)
        in utils.mergeAll (allTCP ++ allHTTP ++ allUDP);
in {
    config.infra.deploy.systems = utils.mergeAll (lib.mapAttrsToList (srvname: srv: processService srv) config.infra.services);
}

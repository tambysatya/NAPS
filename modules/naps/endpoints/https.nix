{flakeRoot, lib, inputs, config, pkgs, ...}:

/*
    HTTP/HTTPS reverse proxy:
        - first the SNO is checked, and HAProxy transfers TLS without termination
        - if no backend matchs, HAProxy tries to terminates the TLS

    Note that the reverse and the forward proxy may not serve the same endpoints, although they can overlap.
    In order to circumvent this, the termination REVERSE proxy listens on 127.0.0.1:9443 while the termination FORWARD
    proxy listens on 127.0.0.2:9443

    Forward proxy: we build one different forward proxy per local environment, since all the local environment does not
    requires to reach the same endpoints.

    TODO: check the haproxy config using haproxy -c -f /etc/haproxy/haproxy.cfg
*/

let
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};
    utils = import ./lib {inherit flakeRoot lib inputs;};


    backend_404 = ''
        backend be_http_404
            mode http
            http-request return status 404
    '';
    mkBackendName = forwardOrReverse: ep@{hostname, ...}: "${forwardOrReverse}_be_http_${hostname}_443";
    mkCrtList = endpoints: pkgs.writeText "haproxy-crt.map" (lib.concatMapStringsSep "\n" (ep@{hostname,...}: "/var/lib/certs/${hostname}.pem") endpoints + "\n");
    mkMap = forwardOrReverse: endpoints: pkgs.writeText "haproxy.map" (lib.concatMapStringsSep "\n" (ep@{hostname,...}: "${hostname}     ${mkBackendName forwardOrReverse ep}") endpoints + "\n");



    generateForwardFrontend = # One forward frontend per environment
        vmenv: hosts: envname: 
        eps: # Map EndpointName Endpoint
        let
           localmap = mkMap "forward" (builtins.attrValues eps);
        in ''
            frontend forward_http_${envname}
                mode tcp
                bind ${utils.envPrivateHostIP config.naps.internal.envs.all.${envname}}:443
                tcp-request inspect-delay 5s
                tcp-request content accept if { req_ssl_hello_type 1 }
                use_backend %[req.ssl_sni,lower,map_dom(${localmap},be_http_404)]
        '';
    /*
        As usual, forward proxies relies on the same "global" backends (since the backends are 
        global, there is no need to create different forward backends pointing to the same 
        endpoints) 
    */
    generateForwardBackend =  
        vmenv: hosts: 
        forward: # Map EnvironmentUID (Map EndpointName Endpoint)
        let
            vmname = utils.envUID vmenv;
            mkBackend = epname: ep@{hostname,...}: 
                ''
                backend forward_be_http_${hostname}_443
                    mode tcp
                    ${utils.backendsConfig vmname ep (hosts.${utils.epToString ep})}
                '';
            allEndpoints = lib.foldl' (attr: attr': attr // attr') {} (builtins.attrValues forward);
        in utils.concatMapAttrsStringsSep "\n" mkBackend allEndpoints;
    generateForward =
        vmenv: hosts:
        forward: # For each environment, which endpoints are reached 
        ''
            ${utils.concatMapAttrsStringsSep "\n" (generateForwardFrontend vmenv hosts) forward}
            ${generateForwardBackend vmenv hosts forward}
        '';

    generateReverse =
        vmenv: consumers:
        reverse: # Map EndpointName (Map InstanceUID ServiceInstance)
        let
            allEndpoints = lib.mapAttrs (epname: _: config.naps.internal.endpoints.all."https".${epname}) reverse; # get the endpoints descriptions

            # splits the endpoints between these that do terminate TLS by themselve (passthrough) and these that request TLS termination 
            # from HAproxy
            parts = utils.partitionAttrs (_: {extraArgs,...}: extraArgs.tls == "passthrough") allEndpoints; 
            passthrough = parts.right; # terminate TLS by themselve
            termination = parts.wrong; # request TLS termination from HAProxy

            # Generate the HAProxy maps
            mapPassthrough = mkMap "reverse_passthrough" (builtins.attrValues passthrough);
            mapTermination = mkMap "reverse_termination" (builtins.attrValues termination);
            crtlist = mkCrtList (builtins.attrValues termination);
        in ''
            frontend reverse_http_passthrough
                mode tcp
                bind ${utils.envIP vmenv}:443
                tcp-request inspect-delay 5s
                tcp-request content accept if { req_ssl_hello_type 1 }
                use_backend %[req.ssl_sni,lower,map_dom(${mapPassthrough},be_passthrough_fallback)]

            # Enter here if the passthrough did not match any backend. This backend routes to the local HTTP frontend
            backend be_passthrough_fallback 
                mode tcp
                server reverse_http_termination 127.0.0.3:443 check check-ssl ca-file /etc/intermediate_ca.crt

            # Since the passthrough failed, we try to terminate the TLS.
            frontend reverse_http_termination
                mode http
                bind 127.0.0.3:443 ssl crt-list ${crtlist}
                option forwardfor
                http-request set-header X-Forwarded-Proto https
                http-request set-header X-Forwarded-Port 443
                use_backend %[req.hdr(host),lower,map_dom(${mapTermination},be_http_404)]
        '';

in 
{
    naps.endpoints.https = {
        extraArgsType = types.submodule {
            options = {
                tls = lib.mkOption {
                    description = "How TLS is implemented through HAproxy. Passthrough means that the service handles TLS while termination means that HAProxy terminates TLS and the endpoints receives an HTTP connection.";
                    type = types.enum ["passthrough" "termination"];
                };
            };
        };
        generateAssets = 
            {extraArgs,hostname,...}: 
            env:
            lib.optionalAttrs 
                (extraArgs.tls == "termination")
                {
                    "tls".${hostname} = {
                            asset = {
                                generateArgs = {inherit hostname;};
                                installArgs = {
                                    owner = "haproxy";
                                    sslFormat = "haproxy";
                                };
                                reload = ["haproxy.service"];
                            };
                            recipients = [(utils.envHostUID env)];
                    };
                };
        generateProxy = vmenv: hosts: consumers: ir@{forward, reverse}:
        ''
            # HTTPs Forward Proxy (always TLS passthrough)
            ${generateForward vmenv hosts forward}

            # HTTPs Reverse Proxy (Checks Passthrough then termination)
            ${generateReverse vmenv consumers reverse}
            ${backend_404}
        '';
        generateFirewall = 
            vmenv: {forward, reverse}:
            let
                # Reverse proxies are always open both on the host and the container 
                processFwReverseInstance =
                    epname: insname: ins:
                    let
                        port = config.naps.internal.endpoints.all."https".${epname}.port;
                    in lib.mkMerge [
                       # On containers only we open the backend port (not on native instances)
                        (lib.optionalAttrs 
                            (utils.runsInContainer ins) 
                            {
                                ${utils.insEnvUID ins}."eth0".tcp = [port];
                            })
                        /* We always open the 443 public port on the host
                           (the only way to reach https endpoints) */
                        {
                            ${utils.envUID vmenv}."enp1s0".tcp = [443];
                        }

                    ];
                fwReverse = endpoint: instances:
                    lib.mkMerge (lib.mapAttrsToList (processFwReverseInstance endpoint) instances);
                allReverseFirewall = lib.mkMerge (lib.mapAttrsToList fwReverse reverse);

                fwForward =
                    localenvuid: endpoints:
                    let 
                        localenv = config.naps.internal.envs.all.${localenvuid};
                        ctFwdPorts = 
                            lib.unique
                                (lib.mapAttrsToList (epname: ep: ep.port) endpoints);
                        fwCtForward =
                            port: {
                                ${utils.envHostUID localenv}.${localenv.host.veth}.tcp = [443];
                            };
                    in lib.optionalAttrs (utils.isContainer localenv) (lib.mkMerge (map fwCtForward ctFwdPorts));
                allForwardFirewall = lib.mkMerge (lib.mapAttrsToList fwForward forward);
            in lib.mkMerge [allReverseFirewall allForwardFirewall];
    };
}



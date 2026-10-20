{flakeRoot, lib, inputs, config, ...}:

/*
    HTTP/HTTPS reverse proxy:
        - first the SNO is checked, and HAProxy transfers TLS without termination
        - if no backend matchs, HAProxy tries to terminates the TLS

    Note that the reverse and the forward proxy may not serve the same endpoints, although they can overlap.
    In order to circumvent this, the termination REVERSE proxy listens on 127.0.0.1:9443 while the termination FORWARD
    proxy listens on 127.0.0.2:9443
*/

let
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};


    mkBackendName = ep@{hostname, ...}: "be_http_${hostname}_443";
    mkCrtList = endpoints: utils.concatMapAttrsStringsSep "\n" (epname: ep@{hostname,...}: "/var/lib/certs/${hostname}.pem") endpoints;
    mkMap = endpoints: utils.concatMapAttrsStringsSep "\n" (epname: ep@{hostname,...}: "${hostname}     ${mkBackendName ep}") endpoints;

    generateHTTPsProxy = 
        vmname: hosts: consumers: exposes: reaches:
        let
            consumersEnvs = lib.mapAttrsToList (_: ins: utils.servicesEnv ins) consumers;
            consumersIfaces = map (env: if utils.isContainer env then env.host.veth else "lo") consumersEnvs;
            consumersIPs = map (env: if utils.isContainer env then utils.evnIP else "127.0.0.1") consumersEnvs;

            mapEndpoints = "";
            crtlist = "";
            mapTerminationTLS = "";
        in {
            firewall."443" = {
                mode = "tcp";
                interfaces = consumersIfaces;
            };
            config = [''
                frontend fe_forward_https
                    mode tcp
                    bind ${lib.concatMapStringsSep "," (ip: "${ip}:443") consumersIPs}
                    tcp-request inspect-delay 5s
                    tcp-request content accept if { req_ssl_hello_type 1 }
                    use_backend %[req.ssl_sni,lower,map_dom(${mapEndpoints},nonSNI_be_forward)]
                backend nonSNI_be_forward
                    mode tcp
                    server fe_forward_http 127.0.0.2:9443 check check-ssl ca-file /etc/intermediate_ca.crt
                frontend fe_forward_http
                    mode http
                    bind 127.0.0.2:9443 ssl crt-list ${crtlist}
                    option forwardfor
                    http-request set-header X-Forwarded-Proto https
                    http-request set-header X-Forwarded-Port 443
                    use_backend %[req.hdr(host),lower,map_dom(${mapTerminationTLS},be_http_404)]
            ''];
        };
    generateHTTPsReverse = 
        vmname: hosts: consumers: exposes: reaches:
        let
            publicIP = config.naps.internal.envs.all.${vmname}.ip;

            mapPassthroughTLS = "";
            mapTerminationTLS = "";
            crtlist = "";

        in {
            firewall."443" = lib.optionalAttrs (exposes != {}){
                mode = "tcp";
                interfaces = ["eth0"];
            };
            config = [''
                frontend fe_reverse_https
                    mode tcp
                    bind ${publicIP}:443
                    tcp-request inspect-delay 5s
                    tcp-request content accept if { req_ssl_hello_type 1 }
                    use_backend %[req.ssl_sni,lower,map_dom(${mapPassthroughTLS},nonSNI_be_reverse)]
                backend nonSNI_be_reverse
                    mode tcp
                    server fe_reverse_http 127.0.0.1:9443 check check-ssl ca-file /etc/intermediate_ca.crt
                frontend fe_reverse_http
                    mode http
                    bind 127.0.0.1:9443 ssl crt-list ${crtlist}
                    option forwardfor
                    http-request set-header X-Forwarded-Proto https
                    http-request set-header X-Forwarded-Port 443
                    use_backend %[req.hdr(host),lower,map_dom(${mapTerminationTLS},be_http_404)]
                backend be_http_404
                    mode http
                    http-request return status 404


            ''];
        };

    generateHTTPProxy = 
        vmname: hosts: consumers: exposes: reaches:
        let
        in {
        };
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
        generateProxy = generateHTTPProxy;
    };
}



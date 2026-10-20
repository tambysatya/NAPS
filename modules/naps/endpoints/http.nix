{flakeRoot, lib, inputs, config, ...}:

/*
    HTTP/HTTPS reverse proxy:
        - first the SNO is checked, and HAProxy transfers TLS without termination
        - if no backend matchs, HAProxy tries to terminates the TLS
*/

let
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};

    

    generateHTTPsProxy = 
        vmname: hosts: consumers: exposes: reaches:
        let
            consumersEnvs = lib.mapAttrsToList (_: ins: utils.servicesEnv ins) consumers;
            consumersIfaces = map (env: if utils.isContainer env then env.host.veth else "lo") consumersEnvs;
            consumersIPs = map (env: if utils.isContainer env then utils.evnIP else "127.0.0.1") consumersEnvs;
            mapPassthroughTLS = "";
            mapTerminationTLS = "";
            crtlist = "";

        in {
            firewall."443" = {
                mode = "tcp";
                interfaces = consumersIfaces;
            };
            config = [''
                frontend fe_proxy_https
                    mode tcp
                    bind ${lib.concatMapStringsSep "," (ip: "${ip}:443") consumersIPs}
                    tcp-request inspect-delay 5s
                    tcp-request content accept if { req_ssl_hello_type 1 }
                    use_backend %[req.ssl_sni,lower,map_dom(${mapPassthroughTLS},nonSNI_be_proxy)]
                backend nonSNI_be_proxy
                    mode tcp
                    server fe_proxy_http 127.0.0.1:9443 check check-ssl ca-file /etc/intermediate_ca.crt
                frontend fe_proxy_http
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
        inherit generateHTTPProxy;
    };
}



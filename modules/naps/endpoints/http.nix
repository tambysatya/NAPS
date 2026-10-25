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
*/

let
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};


    mkBackendName = ep@{hostname, ...}: "be_http_${hostname}_443";
    mkCrtList = endpoints: lib.concatMapStringsSep "\n" (ep@{hostname,...}: "/var/lib/certs/${hostname}.pem") endpoints;
    mkMap = endpoints: lib.concatMapStringsSep "\n" (ep@{hostname,...}: "${hostname}     ${mkBackendName ep}") endpoints;


    generateHTTPProxy = 
        vmname: alleps:
        let
            locallyExposedEndpoints = lib.filterAttrs (_: {locally, ...}: locally.exposedBy != {}) alleps; #need a reverse proxy
            partsExposedEndpoints = utils.partitionAttrs (_: {endpoint,...}: endpoint.extraArgs.tls == "passthrough") locallyExposedEndpoints;
            passthroughEndpoints = partsExposedEndpoints.right;
            terminationEndpoints = partsExposedEndpoints.wrong;

            mapPasstrough= pkgs.writeText "passthrough.map" 
                (mkMap (lib.mapAttrsToList (_: {endpoint,...}: endpoint) passthroughEndpoints));
            mapTermination = pkgs.writeText "termination.map" 
                (mkMap (lib.mapAttrsToList (_: {endpoint,...}: endpoint) terminationEndpoints));
            crtlist = pkgs.writeText "crtlist" 
                (mkCrtList (lib.mapAttrsToList (_: {endpoint,...}: endpoint) terminationEndpoints));
            reverseConfig = lib.optionalString (locallyExposedEndpoints != {}) ''
                frontend fe_reverse_http_passthrough
                    mode tcp
                    bind TODO
                    tcp-request inspect-delay 5s
                    tcp-request content accept if { req_ssl_hello_type 1 }
                    use_backend %[req.ssl_sni,lower,map_dom(${mapPasstrough},nonSNI_be_reverse)]
                backend nonSNI_be_reverse
                    mode tcp
                    server fe_reverse_http_termination 127.0.0.3:443 check check-ssl ca-file /etc/intermediate_ca.crt

                frontend fe_reverse_http_termination
                    mode http
                    bind 127.0.0.3:443 ssl crt-list ${crtlist}
                    option forwardfor
                    http-request set-header X-Forwarded-Proto https
                    http-request set-header X-Forwarded-Port 443
                    use_backend %[req.hdr(host),lower,map_dom(${mapTermination},be_http_404)]


            '';

            locallyReachedEndpoints = lib.filterAttrs (_: {locally, ...}: locally.reachedBy != {}) alleps; #need a forward proxy
            forwardConfig = lib.optionalString (locallyExposedEndpoints != {}) ''
                frontend fe_forward_http
                    mode tcp
                    bind TODO
                    use_backend MAP_OF_ALL_BACKENDS
            '';

            backend_404 = ''
                backend be_http_404
                    mode http
                    http-request return status 404
            '';
        in {
            #config = [reverseConfig forwardConfig backend_404];
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
        generateProxy = vmname: hosts: consumers: ir: "";
    };
}



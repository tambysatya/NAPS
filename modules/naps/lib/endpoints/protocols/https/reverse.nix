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
        backend be_rev_http_404
            mode http
            http-request return status 404
    '';
    mkBackendName = forwardOrReverse: ep@{hostname, ...}: "${forwardOrReverse}_be_http_${hostname}_443";
    mkCrtList = endpoints: pkgs.writeText "haproxy-crt.map" (lib.concatMapStringsSep "\n" (ep@{hostname,...}: "/var/lib/certs/${hostname}.pem") endpoints + "\n");
    mkMap = forwardOrReverse: endpoints: pkgs.writeText "haproxy.map" (lib.concatMapStringsSep "\n" (ep@{hostname,...}: "${hostname}     ${mkBackendName forwardOrReverse ep}") endpoints + "\n");


    generateReverseBackend =
        vmenv: reverse: # Map EndpointName (Map InstanceUID ServiceInstance)
        let
            vmname = utils.envUID vmenv;
            mkBackend = 
                epname: instances:
                let 
                    ep = config.naps.endpoints.all."https".${epname};
                    eptype = ep.extraArgs.tls; # termination or passthrough
                    mode = if eptype == "termination" then "http" else "tcp";
                in ''
                    backend reverse_${eptype}_be_http_${ep.hostname}_443
                        mode ${mode}
                        ${utils.backendsConfig vmname ep instances}
                '';

        in utils.concatMapAttrsStringsSep "\n" mkBackend reverse;
    generateReverse =
        vmenv:
        reverse: # Map EndpointName (Map InstanceUID ServiceInstance)
        let
            allEndpoints = lib.mapAttrs (epname: _: config.naps.endpoints.all."https".${epname}) reverse; # get the endpoints descriptions

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
            
            ${generateReverseBackend vmenv reverse}
        '';

in 
{

    reverseProxy= vmenv: reverse:
    ''
        # HTTPs Reverse Proxy (Checks Passthrough then termination)
        ${generateReverse vmenv reverse}
        ${backend_404}
    '';

}



{flakeRoot, lib, inputs, config, pkgs, ...}:

/* Deploys HAProxy on each VM */

let
    utils = import ../lib {inherit lib inputs flakeRoot;};

    mkBackendI =  # mkBackendI "test.domain.fr" 2 = test2.domain.fr
        domain: i:
        let parts = lib.splitString "." domain;
        in "${builtins.head parts}_${lib.toString i}.${lib.concatStringsSep "." (builtins.tail parts)}";

    generateBackends = 
        mode: name: backends:
        let sortedBackends = builtins.sort (b: b': b.env.priority >= b'.env.priority) backends; #sorted by decreasing priority
            mkBackendEntry = i: {ip, port, ...}:
            ''
                server ${mkBackendI name i} ${ip}:${lib.toString port} check ${if i == 1 then "" else "backup"}
            '';
        in 
        ''
        backend be_${name}
            mode ${mode}
            ${lib.concatStringsSep "\n" (lib.imap mkBackendEntry sortedBackends)}
        '';
    processL4Proxy = 
        mode: # tcp or udp
        name:
        {frontend, backends, extraConfig}: #TODO extraConfig is ignored at the moment
        ''
            frontend ${name}
                mode ${mode}
                bind :${lib.toString frontend.port} #binds on all interfaces. The access will be managed by the firewall
                default_backend be_${name} 
            ${generateBackends mode name backends}
        '';


    generateHTTPProxy=
        allEntries:
        let parts = utils.partitionAttrs (_: {tls,...}: tls) allEntries;
            tls = parts.right;
            nontls = parts.wrong;

            tlsmap = pkgs.writeText "tls.map" (mkMap (builtins.attrNames tls));
            nontlsmap = pkgs.writeText ("nontls.map")(mkMap (builtins.attrNames nontls));


            conf = ''
                frontend https
                    bind *:443
                    mode tcp
                    tcp-request inspect-delay 5s
                    tcp-request content accept if {req_ssl_hello_type 1}
                    use_backend %[req.ssl_sni,lower,map_dom(${nontlsmap},nonSNI_be)]
                backend nonSNI_be
                    mode tcp
                    server nonSNI_fe 127.0.0.1:9443 check check-ssl

                frontend nonSNI_fe
                    bind :9443 ssl crt /var/lib/certs
                    mode http
                    use_backend %[req.hdr(host),lower,map_dom(${tlsmap},http_back)]
                ${utils.concatMapAttrsStringsSep "\n"
                    (name: {backends,...}: generateBackends "tcp" name backends)
                    tls}
                ${utils.concatMapAttrsStringsSep "\n"
                    (name: {backends,...}: generateBackends "http" name backends)
                    nontls}
            '';
        in conf;            

    mkMap = vhosts:
        lib.concatMapStringsSep "\n"
            (name: "${name}         be_${name}")
            vhosts;
            
/*
    generateHTTPProxy =
        allEntries:
        let terminatesTLS = allEntries != {} && (lib.head (builtins.attrValues allEntries)).tls; # Either we terminates TLS for everyone, or for nobody TODO
        in
        ''
            ${generateHTTPFrontends terminatesTLS allEntries}
            ${lib.concatStringsSep "\n"
                (lib.mapAttrsToList (generateHTTPBackend terminatesTLS) allEntries)}
        '';
        
    generateHTTPBackend =
        terminatesTLS:
        vhost:
        {backends, extraConfig,...}:
        let sortedBackends = builtins.sort (b: b': b.env.priority >= b'.env.priority) backends; #sorted by decreasing priority
            mkBackendEntry = i: {ip, port, ...}:
            ''
                server ${mkBackendI vhost i} ${ip}:${lib.toString port} check ${if i == 1 then "" else "backup"}
            '';
        in
        ''
            backend be_${vhost}
                mode ${if terminatesTLS then "http" else "tcp"}
                ${lib.concatStringsSep "\n"
                    (lib.imap mkBackendEntry sortedBackends)}
        '';

    generateHTTPFrontends =  #Note that if the TLS termination is enabled, the proxy will terminate TLS for all vhost. TODO solution ? use two different ips ?
        terminatesTLS:
        allEntries:
        let
            mkFrontEnd =
                vhost:
                    if terminatesTLS
                    then # tls = true: the proxy terminates TLS
                        ''
                            use_backend be_${vhost} if { hdr(host) -i ${vhost} }
                        ''
                    else # else, haproxy checks the SNI to know which backend is requested
                        ''
                            use_backend be_${vhost} if { req.ssl_sni -i ${vhost} }
                        '';
        in 
        ''
            frontend https
                mode ${if terminatesTLS then "http" else "tcp"}
                bind :443 ${if terminatesTLS then "ssl crt /var/lib/certs" else ""}

                option forwardfor
                http-request set-header X-Forwarded-Proto https
                http-request set-header X-Forwarded-Host %[req.hdr(host)]

                ${lib.concatStringsSep "\n" (map mkFrontEnd (builtins.attrNames allEntries))}
        '';
  */  
    processVM = 
        vmname: deploy:
        let tcp = deploy.proxy.tcp;
            udp = deploy.proxy.udp;
            http = deploy.proxy.http;
        in if (tcp != {} || udp != {} || http != {}) 
                then 
                {
                    ${vmname}.config.services.haproxy = {
                        enable = true;
                        config = ''
                                defaults
                                    timeout connect 5s
                                    timeout client 30s
                                    timeout server 30s
                                ${lib.concatStringsSep "\n"
                                    (lib.mapAttrsToList (processL4Proxy "tcp") tcp)}
                                ${lib.concatStringsSep "\n"
                                    (lib.mapAttrsToList (processL4Proxy "udp") udp)}
                                ${if http != {} then generateHTTPProxy http else ""}

                            '';
                    };
                }
                else {};



    allVMs = lib.filterAttrs (_: {env,...}: env.type == "vm") config.infra.deploy.systems;
in {
    config.infra.outputs.systems = utils.mergeAll 
                                        (lib.mapAttrsToList processVM allVMs);
}

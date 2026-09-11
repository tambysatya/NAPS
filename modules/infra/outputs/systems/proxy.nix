{flakeRoot, lib, inputs, config, pkgs, ...}:

/* Deploys HAProxy on each VM */

let
    utils = import ../lib {inherit lib inputs flakeRoot;};

    mkBackendI =  # mkBackendI "test.domain.fr" 2 = test2.domain.fr
        domain: i:
        let parts = lib.splitString "." domain;
        in "${builtins.head parts}_${lib.toString i}.${lib.concatStringsSep "." (builtins.tail parts)}";

    generateBackends = 
        mode: frontport: name: backends:
        let sortedBackends = builtins.sort (b: b': b.env.priority >= b'.env.priority) backends; #sorted by decreasing priority
            mkBackendEntry = i: {ip, port, ...}:
            ''
                server ${mkBackendI name i} ${ip}:${lib.toString port} check ${if i == 1 then "" else "backup"}
            '';
        in 
        ''
        backend be_${name}_${mode}_${lib.toString frontport}
            mode ${mode}
            ${lib.concatStringsSep "\n" (lib.imap mkBackendEntry sortedBackends)}
        '';

    mkBind = 
        vmname: port: public:
        let deploy = config.infra.deploy.systems.${vmname};
            localIP = if deploy.containers == [] then "127.0.0.1" else "192.168.100.1";
            #containersips = map (env: utils.envIP config env) deploy.containers;
        in if public then "0.0.0.0:${lib.toString port}" else "${localIP}:${lib.toString port}";
    generateL4Proxy = 
        vmname:
        mode: # tcp or udp
        port:
        {frontend, backends, extraConfig}: #TODO extraConfig is ignored at the moment
        let bind= mkBind vmname port frontend.public ;
            name = frontend.hostname;
        in ''
            frontend ${name}_${mode}_${lib.toString port}
                mode ${mode}
                bind ${bind} 
                default_backend be_${name}_${mode}_${lib.toString port}
            ${generateBackends mode port name backends}
        '';


    generateHTTPBackends =  # Generates all the backends. Accessibility is handled by maps
        tls: nontls:
        ''
            ${utils.concatMapAttrsStringsSep "\n"
                (name: {backends,...}: generateBackends "http" 443 name backends)
                tls}
            ${utils.concatMapAttrsStringsSep "\n"
                (name: {backends,...}: generateBackends "tcp" 443 name backends)
                nontls}
        '';
    generateHTTPFrontend=
        vmname:
        public:
        allEntries:
        let parts = utils.partitionAttrs (_: {tls,...}: tls) allEntries;
            tls = parts.right;
            nontls = parts.wrong;

            tlsmap = pkgs.writeText "tls.map" (mkMap "http" 443 (builtins.attrNames tls));
            nontlsmap = pkgs.writeText ("nontls.map")(mkMap "tcp" 443 (builtins.attrNames nontls));

            # if private, the maps should also include the backends that are publics

            suffix = if public then "public" else "private";
            bind = mkBind vmname 443 public;

            # We set up a reverse proxy only if there is some services requesting it. Otherwise, we drop an error.
            reverseProxyFront = if tls == {} then 
                ''
                frontend nonSNI_fe_${suffix}
                    mode http
                    http-request return status 404
                ''
                else ''
                frontend nonSNI_fe_${suffix}
                    bind :9443 ssl crt /var/lib/certs
                    mode http
                    option forwardfor
                    use_backend %[req.hdr(host),lower,map_dom(${tlsmap},http_back_${suffix})]
                '';


            conf = ''
                frontend https_${suffix}
                    bind ${bind}
                    mode tcp
                    tcp-request inspect-delay 5s
                    tcp-request content accept if { req_ssl_hello_type 1 }
                    use_backend %[req.ssl_sni,lower,map_dom(${nontlsmap},nonSNI_be_${suffix})]
                backend nonSNI_be_${suffix}
                    mode tcp
                    server nonSNI_fe_${suffix} 127.0.0.1:9443 check check-ssl ca-file /etc/intermediate_ca.crt

                ${reverseProxyFront}

                backend http_back_${suffix}
                    # backend where the host is not found
                    mode http 
                    http-request return status 404
            '';
        in conf;

    mkMap = mode: frontport: vhosts:
        lib.concatMapStringsSep "\n"
            (name: "${name}         be_${name}_${mode}_${lib.toString frontport}")
            vhosts;
            
    processVM = 
        vmname: deploy:
        let tcp = deploy.proxy.tcp;
            udp = deploy.proxy.udp;
            allHTTP = deploy.proxy.http;

            # splitting the http entries between "public" and "private"
            publicp = utils.partitionAttrs (_: attr: builtins.getAttr "public" attr) allHTTP;
            publicHTTP = publicp.right;
            privateHTTP = publicp.wrong;

            # splitting the https backends between TLS terminated and non-tls terminated
            tlsp = utils.partitionAttrs (_: attr: builtins.getAttr "tls" attr) allHTTP;
            tls = tlsp.right;
            nontls = tlsp.wrong;

        in if (tcp != {} || udp != {} || privateHTTP != {} || publicHTTP != {})  
                then 
                {
                    ${vmname}.config.services.haproxy = {
                        enable = true;
                        config = ''
                                    ssl-server-verify none
                                defaults
                                    timeout connect 5s
                                    timeout client 30s
                                    timeout server 30s
                                ${lib.concatStringsSep "\n"
                                    (lib.mapAttrsToList (generateL4Proxy vmname "tcp") tcp)}
                                ${lib.concatStringsSep "\n"
                                    (lib.mapAttrsToList (generateL4Proxy vmname "udp") udp)}

                                # public HTTP (reverse proxies)
                                ${if publicHTTP != {} then generateHTTPFrontend vmname true publicHTTP else ""}

                                # private HTTP (proxy). 
                                ${if privateHTTP != {} then generateHTTPFrontend vmname false allHTTP else ""}

                                #HTTP backends (common for public and private proxy)
                                ${generateHTTPBackends tls nontls}

                            '';
                    };
                }
                else {};



    allVMs = lib.filterAttrs (_: {env,...}: env.type == "vm") config.infra.deploy.systems;
in {
    config.infra.outputs.systems = utils.mergeAll 
                                        (lib.mapAttrsToList processVM allVMs);
}

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


    generateHTTPProxy=
        vmname:
        public:
        allEntries:
        let parts = utils.partitionAttrs (_: {tls,...}: tls) allEntries;
            tls = parts.right;
            nontls = parts.wrong;

            tlsmap = pkgs.writeText "tls.map" (mkMap "http" (builtins.attrNames tls));
            nontlsmap = pkgs.writeText ("nontls.map")(mkMap "tcp" (builtins.attrNames nontls));

            suffix = if public then "public" else "private";
            bind = mkBind vmname 443 public;


            conf = ''
                    ssl-server-verify none
                frontend https_${suffix}
                    bind ${bind}
                    mode tcp
                    tcp-request inspect-delay 5s
                    tcp-request content accept if { req_ssl_hello_type 1 }
                    use_backend %[req.ssl_sni,lower,map_dom(${nontlsmap},nonSNI_be_${suffix})]
                backend nonSNI_be_${suffix}
                    mode tcp
                    server nonSNI_fe_${suffix} 127.0.0.1:9443 check check-ssl ca-file /etc/intermediate_ca.crt

                frontend nonSNI_fe_${suffix}
                    bind :9443 ssl crt /var/lib/certs
                    mode http
                    option forwardfor
                    use_backend %[req.hdr(host),lower,map_dom(${tlsmap},http_back_${suffix})]
                ${utils.concatMapAttrsStringsSep "\n"
                    (name: {backends,...}: generateBackends "http" 443 name backends)
                    tls}
                ${utils.concatMapAttrsStringsSep "\n"
                    (name: {backends,...}: generateBackends "tcp" 443 name backends)
                    nontls}
                backend http_back_${suffix}
                    http-request return status 404
            '';
        in conf;            

    mkMap = mode: vhosts:
        lib.concatMapStringsSep "\n"
            (name: "${name}         be_${name}_${mode}")
            vhosts;
            
    processVM = 
        vmname: deploy:
        let tcp = deploy.proxy.tcp;
            udp = deploy.proxy.udp;
            parts = utils.partitionAttrs (_: attr: builtins.getAttr "public" attr) deploy.proxy.http;
            publicHTTP = parts.right;
            privateHTTP = parts.wrong;

        in if (tcp != {} || udp != {} || publicHTTP != {} || privateHTTP != {})  
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
                                    (lib.mapAttrsToList (generateL4Proxy vmname "tcp") tcp)}
                                ${lib.concatStringsSep "\n"
                                    (lib.mapAttrsToList (generateL4Proxy vmname "udp") udp)}
                                ${if publicHTTP != {} then generateHTTPProxy vmname true publicHTTP else ""}
                                ${if privateHTTP != {} then generateHTTPProxy vmname false privateHTTP else ""}

                            '';
                    };
                }
                else {};



    allVMs = lib.filterAttrs (_: {env,...}: env.type == "vm") config.infra.deploy.systems;
in {
    config.infra.outputs.systems = utils.mergeAll 
                                        (lib.mapAttrsToList processVM allVMs);
}

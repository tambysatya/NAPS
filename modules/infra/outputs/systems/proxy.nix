{flakeRoot, lib, inputs, config, ...}:

/* Deploys HAProxy on each VM */

let
    utils = import ../lib {inherit lib inputs flakeRoot;};

    mkBackendI =  # mkBackendI "test.domain.fr" 2 = test2.domain.fr
        domain: i:
        let parts = lib.splitString "." domain;
        in "${builtins.head parts}_${lib.toString i}.${lib.concatStringsSep "." (builtins.tail parts)}";

    processL4Proxy = 
        mode: # tcp or udp
        name:
        {frontend, backends, extraConfig}: #TODO extraConfig is ignored at the moment
        let sortedBackends = builtins.sort (b: b': b.env.priority >= b'.env.priority) backends; #sorted by decreasing priority
            mkBackendEntry = i: {ip, port, ...}:
            ''
                server ${mkBackendI name i} ${ip}:${lib.toString port} check ${if i == 1 then "" else "backup"}
            '';
        in 
        ''
            frontend ${name}
                mode ${mode}
                bind ${frontend.ip}:${lib.toString frontend.port}
                default_backend be_${name} 
            backend be_${name}
                mode ${mode}
                ${lib.concatStringsSep "\n" (lib.imap mkBackendEntry backends)}
        '';

    generateHTTPProxy =
        allEntries:
        let terminatesTLS = allEntries != {} && (lib.head (builtins.attrValues allEntries)).tls; # Either we terminates TLS for everyone, or for nobody
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
                ${lib.concatStringsSep "\n" (map mkFrontEnd (builtins.attrNames allEntries))}

        '';
    


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
                                defaults:
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


    processFirewall = 
        vmname: deploy:
        let getPorts = 
                proxyEntries:
                let frontends = lib.mapAttrsToList (_: {frontend, ...}: {inherit (frontend) ip port;}) proxyEntries;
                    parts= lib.partition ({ip,...}: ip == "0.0.0.0") frontends; #right = openned everywhere, wrong = open only on the private interface
                in {world= map (builtins.getAttr "port") parts.right;
                    local = map (builtins.getAttr "port") parts.wrong;};
            
            tcp = getPorts deploy.proxy.tcp;
            udp =  getPorts deploy.proxy.udp;
            http = if deploy.proxy.http != {} then [443] else [];
            hascontainersP = config.infra.topology.vms.${vmname}.containers != [];

        in {
           ${vmname}.config.networking.firewall.interfaces =
                utils.mergeAll [
                    {
                        enp1s0 = { /*Direct network interface*/
                            allowedTCPPorts = tcp.world ++ http;
                            allowedUDPPorts = udp.world;
                        };
                    }
                    (if hascontainersP then {
                        eth0 = { /*Containers interface*/
                            allowedTCPPorts = tcp.world ++ tcp.local ++ http;
                            allowedUDPPorts = udp.world ++ udp.local;
                        };
                    }
                    else {})
                ];
        };

    processContainerFirewall = 
        env: {
            ${utils.envUID env}.config.networking.firewall.enable=false;
        };

    allVMs = lib.filterAttrs (_: {env,...}: env.type == "vm") config.infra.deploy.systems;
    allContainers = lib.concatMap 
                        ({deployements,...}:
                            lib.filter ({type,...}: type == "container") (builtins.attrValues deployements)) 
                        (builtins.attrValues config.infra.services);
in {
    config.infra.outputs.systems = utils.mergeAll 
                                        (lib.mapAttrsToList processVM allVMs
                                        ++ lib.mapAttrsToList processFirewall allVMs
                                        ++ map processContainerFirewall allContainers);
}

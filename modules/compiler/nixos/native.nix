{lib, config, inputs, pkgs, naps, registry, vmname, vmconf,...}:

/* Bare metal service managment */

let 
    vars = import "${inputs.self.outPath}/lib/vars.nix" {inherit lib naps registry inputs;};
    comp = import "${inputs.self.outPath}/lib/compiler" {inherit lib inputs pkgs registry naps vmname;};

    processEndpoints = servicename: reg:
        let
            processEndpoint = {host, is_http, port, extraNginxConfig ? "",...}: #creates an nginx reverse proxy if needed
                if is_http
                then comp.generateReverseProxy {fronthost = host; 
                                               backhost = "http://127.0.0.1:${lib.toString port}";
                                               inherit extraNginxConfig;}
                else {}; #TODO pnat
        in lib.mkIf (! config.compiler.options.noEndpoints)
            (lib.mkMerge 
                (lib.map processEndpoint (
                         lib.filter (endpoint: endpoint.is_http)
                                     (reg.endpoints or {}))));

    processSecrets = servicename: reg:
        lib.mkMerge 
            (lib.mapAttrsToList
                   (_: secret: comp.generateSecret secret)
                   (reg.secrets or {}));
    processCertificates = servicename: reg:
        lib.mkMerge
            (lib.mapAttrsToList
                (comp.generateCertificate servicename)
                (reg.sslCertificates or {}));

    # Generates the secrets for a service requesting database accesses
    processDBAccessClient = servicename: reg:
        lib.mkMerge 
            (lib.map
                (access:
                    let secretname = vars.db_key access;
                    in 
                            (comp.generateSecret 
                                { names=[secretname]; inherit (access) owner reload;} ))
                (reg.dbAccesses or []));

    # Generates the secrets for a service requesting S3 accesses
    processS3AccessClient = servicename: reg:
        lib.mkMerge
            (lib.map 
                (access:
                    (comp.generateSecret 
                        {names = [(vars.s3_key access)]; inherit (access) owner reload;}))
                (reg.s3Accesses or []));


    allReloadsOfDBAccess = configuredservices:
        let
            accesses = builtins.concatLists
                            (lib.mapAttrsToList (servicename: reg: (reg.dbAccesses or [])) configuredservices);
            reloads = lib.concatMap (access: access.reload) accesses;
        in comp.mkDBDependencies reloads;

    processVolumes = 
        let
            vm = registry.vms."${vmname}";
            volumes = vm.attachedVolumes;
            dirs = vm.persistentDirectories;
            mountVolumes = lib.mapAttrsToList comp.mountVolumes volumes;

        in comp.compileVolumes vmname;
in{
   config = let 
                configuredservices = if builtins.hasAttr "services" vmconf
                                        then lib.filterAttrs (srv: _: builtins.elem srv vmconf.services) registry.services
                                        else {};
                hostedservices = if builtins.hasAttr "containers" vmconf
                                    then lib.filterAttrs (srv: _: builtins.elem srv vmconf.containers) registry.services
                                    else {};
                #configuredservices = lib.filter (srv: builtins.hasAttr srv registry) vmservices;
                _ = builtins.seq registry null;
            #in lib.mkIf cfg.enable (builtins.seq configuredservices {});
            in (lib.mkMerge [
                        (lib.mkMerge
                            (lib.mapAttrsToList processEndpoints configuredservices))
                        (lib.mkMerge
                            (lib.mapAttrsToList processSecrets configuredservices))
                        (lib.mkMerge
                            (lib.mapAttrsToList processCertificates (configuredservices // hostedservices)))
                        (lib.mkMerge
                            (lib.mapAttrsToList processDBAccessClient configuredservices))

                        # Generates the dependencies for each service depending on an access TODO factorize ?
                        (allReloadsOfDBAccess configuredservices)

                        (lib.mkMerge
                            (lib.mapAttrsToList processS3AccessClient configuredservices))
                        (lib.mkIf (!config.compiler.options.noMounts) processVolumes)
                    ]);
}

{inputs, lib, infra, pkgs,...}:

let
    utils = import "${inputs.self.outPath}/lib" {inherit lib inputs;};
    
    domain = infra.topology.domain;
    clean = str: lib.replaceStrings ["/" "-"] ["_" "_"] str;
    ageUID = env: clean (utils.envUID env);
    generateServiceDeployement =
        srvname:
        srv@{endpoints, links, persistent, store, ...}:
        env:
        let uid = utils.envUID env;
            processTCP = 
                tcp@{hostname, port,...}:
                ''
                    ${uid}_${clean srvname}_${lib.toString port} [
                        label = "${hostname}:${lib.toString port}";
                        ];
                '';
        in ''
            subgraph cluster_${uid} {
                label = "${utils.envUID env}";
               ${lib.concatMapStringsSep "\n" processTCP endpoints.tcp} 
            };
        '';
    generateLinks =
        srvname:
        endpoints:
        links@{s3, postgres,...}:
        env:
        let uid = utils.envUID env;
            s3hosts = infra.deploy.endpoints."s3.${domain}";
            pghosts = infra.deploy.endpoints."postgres.${domain}";

            connect' = tgtname: tgt: tcp@{port,...}:  "${uid}_${clean srvname}_${lib.toString port} -> ${ageUID tgt.env}_${tgtname}";
            connect = tgtname: tgt: lib.concatMapStringsSep "\n" (connect' tgtname tgt) endpoints.tcp;

        in ''
            ${if s3 != [] 
                then lib.concatMapStringsSep "\n" (connect "garage_3900") s3hosts
                else ""} 
            ${if postgres != []
                then lib.concatMapStringsSep "\n" (connect "postgres_5432") pghosts
                else ""} 
        '';
    generateServiceNodes = 
        srvname:
        srv@{deployements,...}:
        lib.concatStringsSep "\n" (lib.mapAttrsToList (uid: env: generateServiceDeployement srvname srv env) deployements);

    generateServiceEdges =
        srvname:
        srv@{deployements,...}:
        lib.concatStringsSep "\n" (lib.mapAttrsToList (uid: env: generateLinks srvname srv.endpoints srv.links env) deployements);

in {
    inherit generateServiceNodes generateServiceEdges;
}

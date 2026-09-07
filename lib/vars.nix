/* Standard definitions of names, paths... */

{lib, inputs,...}:

let

    #paths 
    ssl_root = "/var/lib/ssl";
    ssl_basedir = name: "${ssl_root}/${name}";
    ssl_crt_path = name: "${ssl_basedir name}/${name}.crt";
    ssl_key_path = name: "${ssl_basedir name}/${name}.key";

    #naming conventions
    container_id = vmname: service: "${vmname}-${service}"; #returns the containers ID
    s3_key_id = access@{bucket,...}: "s3-${bucket}.id";
    s3_key = access@{bucket,...}: "s3-${bucket}.key";
    db_key = access@{database, ...}: "db-${database}.key";
    
    directory_id = serviceuid: path: "${serviceuid}:${path}";
    envUID = env: if builtins.isString env then env
                  else if env.type == "vm" then env.host
                  else env.host.container;
    envHost = env: if builtins.isString env then env
                   else if env.type == "vm" then env.host
                   else env.host.vm;

    hostDeployementEnv = # get the hosting deployement environment
        env: {inherit (env) priority tags; type="vm"; host=envHost env;};

in {
    inherit ssl_root ssl_basedir ssl_crt_path ssl_key_path;
    inherit s3_key s3_key_id db_key;
    inherit directory_id;
    inherit envUID envHost hostDeployementEnv;
}

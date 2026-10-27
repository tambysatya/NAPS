/* Standard definitions of names, paths... */

{lib, inputs,...}:

let

    types = import ./types {inherit lib inputs;};

    #paths 
    paths = {
        secrets = "/var/lib/secrets";
        pemdir = "/var/lib/certs";
        git = ".secrets/git";
        out = ".secrets/out";
        perVM = ".secrets/perVM";
    };
    ssl_crt_path = name: "${paths.secrets}/${name}/${name}.crt";
    ssl_key_path = name: "${paths.secrets}/${name}/${name}.key";

    #naming conventions
    default_service_id = hostname: service: "def-${hostname}-${service}"; # hostname is a vmname or a ctname
    container_id = vmname: service: "${vmname}-${service}"; #returns the containers ID
    s3_root = access@{bucket, ...}: "s3-${bucket}";
    s3_key_id = access@{bucket,...}: "${s3_root access}.id";
    s3_key = access@{bucket,...}: "${s3_root access}.key";
    db_root = access@{database,...}: "db-${database}";
    db_key = access@{database, ...}: "${db_root access}.key";
    ssh_base_name = name: "${name}-ssh";
    store_base_name = name: "${name}-cache";
    store_key_name = name: "${name}-cache.key";
    ldap_root = access@{olcRootDN,...}: "ldap-${olcRootDN}";
    ldap_key = access@{olcRootDN,...}: "${ldap_root access}.key"; #TODO
    
    directory_id = serviceuid: path: "${serviceuid}:${path}";
    envUID = env: if builtins.isString env then env
                  else if env.type == "vm" then env.host
                  else env.host.container;
    envHostUID = env: if builtins.isString env then env
                   else if env.type == "vm" then env.host
                   else env.host.vm;
    isContainer = env: env.type == "container";
    isVM = env: ! isContainer env;

    hostDeployementEnv = # get the hosting deployement environment
        env: {inherit (env) priority tags; type="vm"; host=envHostUID env;};
    hostIP = env: if isContainer env then env.host.publicHostAddress else env.ip;
    envIP = env: env.ip;
    envPrivateHostIP = env: # IP of the host on the private network
        if isContainer env 
        then env.host.privateHostAddress
        else "127.0.0.1"; 

    epToString = {hostname, port, ...}: "${hostname}:${lib.toString port}";

    insEnv = ins@{deployement,...}: deployement;
    insEnvUID = ins: envUID (insEnv ins);
    insIP = ins: envIP (insEnv ins); # public IP address

    runsInContainer = ins: isContainer (insEnv ins);
    runsInVM = ins: isVM (insEnv ins);

    insHostUID = ins: envHostUID (insEnv ins); # Host environment
    insHostIP = ins: hostIP (insEnv ins); # Host public IP
    insPrivateHostIP = ins: envPrivateHostIP (insEnv ins); # Host private IP = 127.0.0.1 if native, host veth IP otherwise

in {
    inherit paths;
    inherit default_service_id;
    inherit ssh_base_name store_base_name store_key_name;
    inherit ssl_crt_path ssl_key_path;
    inherit s3_root s3_key s3_key_id db_root db_key ldap_root ldap_key;
    inherit directory_id;
    inherit isContainer isVM;
    inherit envUID envHostUID hostDeployementEnv hostIP envIP envPrivateHostIP;
    inherit insEnv insEnvUID insIP runsInContainer runsInVM insHostUID insHostIP insPrivateHostIP;
    inherit epToString;
}

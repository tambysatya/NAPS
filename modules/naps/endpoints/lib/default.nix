{flakeRoot, lib, inputs,...}:

let

    utils = import "${flakeRoot}/lib" {inherit lib inputs;};


    backendConfig = 
        vmname: ep@{hostname, port,...}: i: ins@{name, value}: 
        let 
            env = utils.insEnv value;
            ip = if utils.envUID env == vmname then "127.0.0.2" else utils.envIP env;
        in "\tserver ${name}_tcp_${lib.toString port} ${ip}:${lib.toString port} check ${lib.optionalString (i > 1) "backup"}";
    backendsConfig = vmname: ep: instances:
        let sorted = lib.sort (attr: attr': attr.value.priority > attr'.value.priority) (lib.attrsToList instances);
        in lib.concatStringsSep "\n" (lib.imap (backendConfig vmname ep) sorted);

    bindConfig = vmname: ep@{port,...}: instances:
        let getIP = _: ins@{deployement, ...}:
                if utils.envUID deployement == vmname 
                then "127.0.0.1:${lib.toString port}" 
                else "${deployement.host.privateHostAddress}:${lib.toString port}"; 
        in utils.concatMapAttrsStringsSep 
            ", " 
            getIP
            instances;



in 

utils // {
    inherit backendsConfig bindConfig;
}

{flakeRoot, lib, inputs, config, ...}:

let
    utils = import ./lib.nix {inherit lib inputs flakeRoot;};
    allLetters = lib.stringToCharacters "bcdefghijklmnopqrstuvwxyz"; #starting from b since /dev/vda is reserved for the root file system;

    
    generateMappings = 
        vmname: disks:
        let
            generateMapping = 
                host:
                {mount,type, fs, options, ...}:
                letter: {
                    ${vmname}.storage.mappings = [{inherit host mount type letter fs options;}];
                };
        in utils.mergeAll (lib.zipListsWith (f: x: f x) (lib.mapAttrsToList generateMapping disks) allLetters);

    generateBinds = 
        diruid:
        {env, path, bindTo, mode, owner, reload, mount,...}:
        {
            ${utils.envHost env}.storage = {
                binds = if path != bindTo && env.type == "vm"
                        then [{what=path; where = bindTo; inherit mode owner reload;}]
                        else [];
                containers = if env.type == "container"
                             then {
                                    ${utils.envUID env}.${bindTo} = {hostPath=path; inherit mode owner reload;};
                                  }
                             else {};
                ensureDirs = if path != bindTo then [{inherit path mode owner reload mount env;}] else [];
            };
        };


    processSecret = 
        secret@{content, recipients, type}:
        let secretFiles =  utils.secretFiles secret;
            processRecipient = env:
                if env.type == "vm" then {}
                else if env.type == "container" then {
                    ${utils.envHost env}.storage.containers.${utils.envUID env} =
                        utils.mergeAll 
                            (map 
                                (secname:
                                 {
                                    "/var/lib/secrets/${secname}" = {
                                        hostPath = "/var/lib/secrets/${secname}";
                                        # These functions implement default values if the field is not filled (secrets is an heterogeneous list)
                                        owner = utils.secretOwner secret;
                                        reload = utils.secretReload secret;
                                        mode = utils.secretMode secret;
                                        isReadOnly = true;
                                    };
                                 })
                             secretFiles);
                }
                else throw "deploy.storage.processSecret not implemented for env ${env.type}";
        in utils.mergeAll (map processRecipient recipients);

in 
{
    imports = [./options];
    infra.deploy.systems = utils.mergeAll 
                                (lib.mapAttrsToList generateMappings config.infra.volumes.perVM
                                ++ lib.mapAttrsToList generateBinds config.infra.volumes.perDirectory
                                ++ map processSecret config.infra.secrets.allSecrets);
}

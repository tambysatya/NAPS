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
                                    ${utils.envUID env}.${bindTo} = {hostPath=path; isReadOnly = false;};
                                  }
                             else {};
                ensureDirs = if path != bindTo then [{inherit path mode owner reload mount env;}] else [];
            };
        };


    processEnvAsset = 
        envuid:
        assetname:
        asset@{installArgs, ...}:
        let env = config.naps.envs.all.${envuid};
            path = installArgs.path;
        in lib.optionalAttrs (env.type == "container") {
            ${utils.envHost env}.storage.containers.${utils.envUID env}.${path} = {
                    hostPath = path;
                    isReadOnly = true;
             };

        };

    processAssets =
        envuid: assets: utils.mergeAll (lib.mapAttrsToList (processEnvAsset envuid) assets);
in 
{
    imports = [./options];
    naps.deploy.systems = utils.mergeAll 
                                (lib.mapAttrsToList generateMappings config.naps.volumes.perVM
                                ++ lib.mapAttrsToList generateBinds config.naps.volumes.perDirectory
                                ++ lib.mapAttrsToList processAssets config.naps.assets.perEnv);
}

{flakeRoot, lib, inputs, path, pkgs, ...}:

let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};
    generateSSLString = 
        filename:
        {opensslSize, opensslType,...}:
        let dstPath = "${utils.paths.out}/${filename}";
        in ''
            [[ ! -f ${dstPath} ]] && ${lib.getExe pkgs.openssl} rand -${opensslType} ${lib.toString opensslSize} \
                                                | tr -d "\n" \
                                                > ${dstPath}
        '';
 

    give = filename: envs: 
        let filepath = "${utils.paths.out}/${filename}";
            target = env: "${utils.paths.perVM}/${utils.envHost env}/${filename}";
        in lib.concatMapStringsSep "\n" (env: ''cp -r ${filepath} ${target env}'') envs;

    install = 
        filename: 
        type:
        {path, owner, group ? null, mode ? null,  ...}:
        let mnttgt = "/mnt${path}";
            group' = if group == null then owner else group;
            mode' = if mode != null then mode else {"file" = "0400"; "dir" = "500";}.${type};
        in ''
           cp -R "$1/${filename}" ${mnttgt}
           chown -R ${owner} ${mnttgt}
           chgrp -R ${group'} ${mnttgt}
           chmod -R ${mode'} ${mnttgt}
        '';




in lib // utils // {
    inherit generateSSLString;
    inherit give;
    inherit install;
}

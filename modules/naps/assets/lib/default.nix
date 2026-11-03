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
 

    give = config: filename: envs: 
        let filepath = "${utils.paths.out}/${filename}";
            target = envname:
                let env = config.naps.internal.envs.all.${envname};
                    path = if utils.isContainer env 
                           then "${utils.envHostUID env}/${envname}" else envname;
                in "${utils.paths.perVM}/${path}/${filename}";
        in lib.concatMapStringsSep "\n" (envname: ''cp -r ${filepath} ${target envname}'') envs;

    install = 
        filename: 
        type: # if type == dir, the directory will be in 111 and the permissions specified in 'mode' will be applied to all files
        {path, owner, group ? null, mode ? "0400",  ...}: 
        let mnttgt = ''"$PREFIX"${path}'';
            group' = if group == null then owner else group;
        in ''
           cp -R "$1/${filename}" ${mnttgt}
           chown -R ${owner} ${mnttgt}
           chgrp -R ${group'} ${mnttgt}
           chmod -R ${mode} ${mnttgt}
           ${lib.optionalString 
                (type == "dir")
                "chmod 111 ${mnttgt}"}
        '';




in lib // utils // {
    inherit generateSSLString;
    inherit give;
    inherit install;
}

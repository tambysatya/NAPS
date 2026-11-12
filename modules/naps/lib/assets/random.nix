{flakeRoot, lib, inputs, pkgs, path, config, ...}:

/* Assets generated using openssl rand */

let

    utils = import ./utils {inherit flakeRoot lib inputs path pkgs;};
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};
    paths = utils.paths;
    domain = config.naps.topology.domain;

    generatePlain = 
        filename:
        args:
        ''
            ${utils.generateSSLString filename args}
            cp -R ${paths.out}/${filename} ${paths.git}

        '';

    generateS3 = 
        assetname:
        access@{bucket,...}:
        ''
            mkdir -p ${paths.out}/${assetname}
            ${generatePlain "${assetname}/${utils.s3_key_id access}" {opensslSize=32; opensslType="hex";}}
            ${utils.generateSSLString "${assetname}/${utils.s3_key access}" {opensslSize=32; opensslType="hex";}}
        '';

    generateDB = 
        assetname: access:
        utils.generateSSLString (utils.db_key access) {opensslSize=64; opensslType = "base64";};

    generateLDAP = 
        assetname: access@{olcRootDN,...}:
        let filename = utils.ldap_key access;
        in ''  
            ${utils.generateSSLString filename {opensslSize=64; opensslType = "base64";}}
            cat ${paths.out}/${filename} \
            | ${pkgs.openldap}/bin/slappasswd -s -- -h "{SSHA}" \
            > ${paths.out}/${filename}.ssha

            cp ${paths.out}/${filename}.ssha ${paths.git}
        '';


    installS3 = 
        assetname:
        access:
        installArgs@{path, ...}:
        utils.install assetname "dir" installArgs;
       
    installDB =
        assetname:
        access@{database,...}:
        installArgs@{path, pgpass ? false, owner,...}:
        utils.install assetname "file" installArgs;

    installLDAP =
        assetname: access:
        installArgs@{hashed ? true, ...}:
        lib.optionalString
            (!hashed)  # if the password is supposed to be hashed, it is already stored publicly so we dont install the password
            (utils.install (utils.ldap_key access) "file" installArgs);




in {

naps.lib.assets.plain = {
    apply = {
        generate = acc: assetname: args: acc ++ [(generatePlain assetname args)];
        install = assetname: args: ""; #no installation script since the file goes in the store
    };
};
naps.lib.assets.password = {
    apply = {
        generate = acc: assetname: args: acc ++ [(utils.generateSSLString assetname args)];
        install = assetname: args: utils.install assetname "file" args.installArgs;
    };
};
naps.lib.assets.postgres = {
    apply = {
        generate = acc: assetname: args: acc ++ [(generateDB assetname args)];
        install = assetname: args: installDB assetname args.generateArgs args.installArgs;
    };
};
naps.lib.assets.s3 = {
    apply = {
        generate = acc: assetname: args: acc ++ [(generateS3 assetname args)];
        install = assetname: args: installS3 assetname args.generateArgs args.installArgs;
    };
};
naps.lib.assets.ldapssha = {
    apply = {
        generate = acc: assetname: args: acc ++ [(generateLDAP assetname args)];
        install = assetname: args: installLDAP assetname args.generateArgs args.installArgs;
    };
};
}



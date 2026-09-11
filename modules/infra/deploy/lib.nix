{flakeRoot, lib, inputs, ...}:

let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};
    certToSecret = 
        cert@{hostname,owner, reload,...}:
        let crt = "${hostname}.crt";
            key = "${hostname}.key";
            mkSecret = name: {filename=name; inherit owner; mode="0400";};
        in [(mkSecret crt) (mkSecret key)];
    s3ToSecret = access:
                    [
                        {filename=utils.s3_key_id access; inherit (access) owner reload; mode="0400";}
                        {filename=utils.s3_key access; inherit (access) owner reload; mode="0400";}
                    ];
    dbToSecret = access: {filename=utils.db_key access; inherit (access) owner reload; mode="0400";};
    ldapToSecret = access: {inherit (access) filename owner reload; mode = "0400";};

    secretFiles = 
        {type, content,...}:
        {
            "plain" = [];
            "password" = [content.filename];
            "ldapssha" = [content.filename];
            "sslCertificate" = let host = content.hostname;
                               in ["${host}.crt" "${host}.key"];
            "postgres" = [(utils.db_key content) "${utils.db_key content}.pgpass"];
            "s3" = [(utils.s3_key_id content) (utils.s3_key content)];
            "step-ca" = ["intermediate_ca_key" "ca-password.key"];
        }.${type};

    secretOwner = 
        {type, content,...}: if content ? owner then content.owner else "root";
    secretReload = 
        {type, content,...}: if content ? reload then content.reload else [];
    secretMode= 
        {type, content,...}: if content ? mode then content.mode else "0400";






    envIP = config: env: config.infra.deploy.systems.${utils.envUID env}.ip;
    envHostIP = config: env:  # Retrieves the IP of the host vm if the env is a container
        if env.type == "vm"
            then envIP config env
            else config.infra.deploy.systems.${env.host.vm}.ip;

    hostHasContainers = config: env:
        let host = if env.type == "vm" then env.host else env.host.vm;
        in config.infra.topology.vms.${host}.containers != [];

in utils // {
    inherit certToSecret s3ToSecret dbToSecret ldapToSecret;
    inherit secretFiles secretOwner secretReload secretMode;
    inherit envIP envHostIP hostHasContainers;
}

{lib, inputs, config, flakeRoot, ...}:

let
    utils = import ../lib {inherit lib inputs flakeRoot;};
        

    domain = config.naps.topology.domain;
    loggingCertName = vmname: "journald-${vmname}.${domain}";
    getEnv = vmname: utils.mkVMEnv vmname;

    mkSecret = vmname: 
    [{
        type = "sslCertificate";
        content = {
            hostname = loggingCertName vmname;
            owner = "systemd-journal-upload";
            reload = ["systemd-journal-upload.service"];
        };
        recipients = [(getEnv vmname)];
    }];

    enableLogging = 
        vmname: vmconf: {
            config.services.journald.upload = {
                enable = true;
                settings.Upload = {
                    ServerCertificateFile = "/var/lib/secrets/${loggingCertName vmname}.crt";
                    ServerKeyFile = "/var/lib/secrets/${loggingCertName vmname}.key";
                    TrustedCertificateFile = "/etc/root_ca.crt";
                    URL = "https://journald.${domain}:443";
                };
            };
        };

    loggingVMs = lib.filterAttrs (_: {centralizeLogs,...}: centralizeLogs) config.naps.topology.vms;

in {
    naps.secrets.allSecrets = lib.concatMap mkSecret (builtins.attrNames loggingVMs);
    naps.secrets.perVM = lib.mapAttrs (vmname: _: mkSecret vmname) loggingVMs;
    naps.outputs.systems = lib.mapAttrs enableLogging loggingVMs;
}

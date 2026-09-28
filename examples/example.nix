{path, ...}:
{
  #imports = [inputs.small-lab.nixosModules.naps];
  config.naps.topology = {
/*
    flakePath = path;
    secretsPath = ".secrets";
    caURL = "ca.local.fr";
*/
    provisionerHost = "provisioning.local";
    provisionerAddr = "192.168.1.200";
    domain = "local.fr";
    vmSubnet = "192.168.1.0/24";
    dns = ["8.8.8.8" "8.8.4.4"];
    gateway = "192.168.1.1"; #default gateway
    rootSSHPublicKeys = [
    ];
    services = {
        "keycloak-main".is = "keycloak";
        "stepca-main".is = "step-ca";
        "ldap-main".is = "openldap";
        "s3-main".is = "garage";
        "pg-main".is = "postgres";
        "hydra-main".is = "hydra";
        "log-main".is = "journald-remote";
        "nc-main".is = "nextcloud";
        "git-main".is = "forgejo";
    };
    hosts = {
      cpuhost1 = {
        ipAddress = "192.168.2.200";
      };
    };
    vms = {
      identity = {
        host = "cpuhost1";
        vcpu = 4;
        memory = 8000;
        ip = "192.168.1.200";
        #services = ["step-ca" "openldap"];
        services = ["stepca-main" "keycloak-main"];
        disks = [
            {type="disk"; path="/dev/pvhdd/ldap"; mount="/var/lib/openldap/data"; fs="xfs";}
        ];
    };
    };};



}


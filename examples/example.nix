{path, ...}:
{
  #imports = [inputs.small-lab.nixosModules.infra];
  config.infra.topology = {
/*
    flakePath = path;
    secretsPath = ".secrets";
    caURL = "ca.local.fr";
*/
    provisionerAddr = "provisioning.local";
    domain = "local.fr";
    vmSubnet = "192.168.1.0/24";
    dns = ["8.8.8.8" "8.8.4.4"];
    gateway = "172.31.1.1";
    rootSSHPublicKeys = [
    ];
    services = {
        "keycloak-main".is = "keycloak";
        "stepca-main".is = "step-ca";
        "ldap-main".is = "openldap";
        "s3-main".is = "garage";
        "pg-main".is = "postgres";
        "nc-main".is = "nextcloud";
        "hydra-main".is = "hydra";
        "log-main".is = "journald-remote";
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
        services = ["keycloak-main" "stepca-main" "ldap-main"];
        disks = [
            {type="disk"; path="/dev/pvhdd/ldap"; mount="/var/lib/openldap/data"; fs="xfs";}
        ];

      };
      storage = {
        host = "cpuhost1";
        vcpu = 4;
        memory = 8000;
        disks = [
            {type="disk"; path="/dev/pvhdd/s3"; mount="/var/lib/garage/data"; fs="xfs"; options=["nofail"];}
            {type="disk"; path="/dev/pvhdd/s3_metadatas"; mount="/var/lib/garage/meta"; fs="xfs"; options=["nofail"];}
        ];

        ip = "192.168.1.201";
        services = ["s3-main"]; 
      };
      postgres = {
        host = "cpuhost1";
        vcpu = 4;
        memory = 8000;
        disks = [
            {type="disk"; path="/dev/ssd/postgres"; mount="/var/lib/postgresql"; fs="xfs"; options=["nofail"];}
        ];

        ip = "192.168.1.202";
        #containers = ["pg-main"]; 
        services = ["pg-main"]; 
      };
      apps = {
        host = "cpuhost1";
        vcpu = 8;
        memory = 16000;

        ip = "192.168.1.203";
        services = ["nc-main"]; 
        #containers = ["nc-main"]; 
        disks = [
            {type="qcow"; path="persistent"; fs="ext4"; shared=true;}
            {type="qcow"; path="test"; mount="/srv/persistent"; fs="ext4"; shared=false;}
        ];
      };
      build = {
        host = "cpuhost1";
        vcpu = 8;
        memory = 8000;

        ip = "192.168.1.204";
        services = ["hydra-main"];
      };
      /*
      log  = {
        host = "cpuhost1";
        vcpu=1;
        memory=1024;
        ip = "192.168.1.205";
        services = ["log-main"];
      };
      */

    };
  };

}


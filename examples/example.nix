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
            {type="disk"; path="/dev/pvhdd/s3"; mount="/srv/data"; fs="xfs"; options=["nofail"];}
            {type="disk"; path="/dev/pvhdd/s3_metadatas"; mount="/srv/meta"; fs="xfs"; options=["nofail"];}
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
        #services = ["nc-main"]; 
        containers = ["nc-main" "git-main"]; 
        disks = [
            {type="qcow"; path="persistent"; fs="ext4"; shared=true;}
            {type="qcow"; path="test"; mount="/srv/persistent"; fs="ext4"; shared=false;}
            {type="disk"; path="/dev/ssd/forgejo"; mount="/var/lib/forgejo"; fs="xfs"; shared=false;}
        ];
      };
      build = {
        host = "cpuhost1";
        vcpu = 8;
        memory = 8000;

        ip = "192.168.1.204";
        services = ["hydra-main"];
        disks = [
            {type="disk"; path="/dev/ssd/hydra"; mount="/nix"; fs="xfs"; options=["noatime"];}
            {type="disk"; path="/dev/pvhdd/hydra"; mount="/var/lib/hydra/cache"; fs="xfs"; options=["noatime"];}
        ];


      };
      logs  = {
        host = "cpuhost1";
        vcpu=1;
        memory=1024;
        ip = "192.168.2.205";
        services = ["log-main"];
        disks = [
            {type="disk"; path="/dev/pvhdd/logs"; mount="/var/log/journal/remote"; fs="xfs"; options=["noatime"];}
        ];



        #you can override default network settings
        gateway = "192.168.2.1";
        bridge = "br0"; 
      };

    };
  };

}


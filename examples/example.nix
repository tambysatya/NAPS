{location, ...}:
{
  #imports = [inputs.small-lab.nixosModules.naps];
  config.naps.topology = {
/*
    flakePath = location;
    secretsPath = ".secrets";
    caURL = "ca.local.fr";
*/

    provisioner = {
        hostname = "provisioning.local";
        ips = ["192.168.1.200"];
        ssh = "naps@192.168.1.200";
    };
    domain = "local.fr";
    vmSubnet = "10.0.0.0/24";
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
        "nc-bkup".is = "nextcloud";
        "git-main".is = "forgejo";
        "pg-backup".is = "postgres";
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
        ip = "10.0.0.50";
        #services = ["step-ca" "openldap"];
        services = ["keycloak-main" "stepca-main" "ldap-main" "pg-backup"];
        disks = [
            {type="disk"; location="/dev/pvhdd/ldap"; mount="/var/lib/openldap/data"; filesystem="xfs";}
            {type="disk"; location="/dev/ssd/postgres-back"; mount="/var/lib/postgresql"; filesystem="xfs"; options=["nofail"];}
        ];

      };
      storage = {
        host = "cpuhost1";
        vcpu = 4;
        memory = 8000;
        ip = "10.0.0.51";
        disks = [
            {type="disk"; location="/dev/pvhdd/s3"; mount="/srv/data"; filesystem="xfs"; options=["nofail"];}
            {type="disk"; location="/dev/pvhdd/s3_metadatas"; mount="/srv/meta"; filesystem="xfs"; options=["nofail"];}
        ];

        services = ["s3-main"]; 
      };
      postgres = {
        host = "cpuhost1";
        vcpu = 4;
        memory = 8000;
        ip = "10.0.0.52";
        disks = [
            {type="disk"; location="/dev/ssd/postgres"; mount="/var/lib/postgresql"; filesystem="xfs"; options=["nofail"];}
        ];

        #containers = ["pg-main"]; 
        services = ["pg-main"]; 
      };
      apps = {
        host = "cpuhost1";
        vcpu = 8;
        memory = 16000;

        ip = "10.0.0.53";
        services = ["nc-bkup"]; 
        containers = ["nc-main" "git-main"]; 
        disks = [
            {type="qcow"; location="persistent"; filesystem="ext4"; shared=true;}
            {type="qcow"; location="test"; mount="/srv/persistent"; filesystem="ext4"; shared=false;}
            #{type="disk"; location="/dev/ssd/forgejo"; mount="/var/lib/forgejo"; filesystem="xfs"; shared=false;}
        ];
      };
      build = {
        host = "cpuhost1";
        vcpu = 8;
        memory = 8000;

        ip = "10.0.0.54";
        services = ["hydra-main"];
        disks = [
            {type="disk"; location="/dev/ssd/hydra"; mount="/nix"; filesystem="xfs"; options=["noatime"];}
            {type="disk"; location="/dev/pvhdd/hydra"; mount="/var/lib/hydra/cache"; filesystem="xfs"; options=["noatime"];}
        ];


      };
      
      logs  = {
        host = "cpuhost1";
        vcpu=1;
        memory=1024;
        ip = "10.0.0.55";
        services = ["log-main"];
        disks = [
            {type="disk"; location="/dev/pvhdd/logs"; mount="/var/log/journal/remote"; filesystem="xfs"; options=["noatime"];}
        ];



        #you can override default network settings
        gateway = "192.168.2.1";
        bridge = "br0"; 
      };

    };
  };

}

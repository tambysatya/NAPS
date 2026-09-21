{path, ...}:
{
  config.naps.topology = {

    domain = "local.fr";

    /* Specifies here the Host and the default IP address of the provisioning server 
       on which the secrets will be reached. No DNS is required, the hostname will be 
       used to generate a TLS certificate to ensure an encrypted transport of the 
       secrets.
    */
    provisionerHost = "provisioning.local";
    provisionerAddr = "192.168.1.200";

    vmSubnet = "192.168.1.0/24"; #Unused yet TODO

    /* Network configuration of the domain */
    dns = ["8.8.8.8" "8.8.4.4"];
    gateway = "192.168.1.1"; #default gateway

    rootSSHPublicKeys = [
        # Add here the root SSH keys that will be allowed on every machine
    ];
    services = {
        # Declare services instances here in the form: unique_identifier.is serviceName 

        "stepca-main".is = "step-ca"; # SmallSTEP : TLS automated Certificate Authority
        "keycloak-main".is = "keycloak"; # Single Sign-in for webapps
        "ldap-main".is = "openldap"; 
        "s3-main".is = "garage"; # S3 storage
        "pg-main".is = "postgres"; # Centralized postgres database
        "hydra-main".is = "hydra"; # Building and cache system. Requires Postgres
        "log-main".is = "journald-remote"; #By default, centralized logging is enabled. It is thus mandatory to have a service to collect logs (TODO)
        "nc-main".is = "nextcloud"; # Dropbox-like webapp. Requires postgres and S3
        "git-main".is = "forgejo"; # Code forge: Requires postgres and S3
    };
    hosts = {
      # Declare bare-metal KVM host addresses 
      cpuhost1 = {
        ipAddress = "192.168.2.200";
      };
    };

    vms = {
      # Declare VM configurations:
      identity = {
        host = "cpuhost1";
        vcpu = 4;
        memory = 8000; Memory in MiB
        ip = "192.168.1.200";
        services = ["keycloak-main" "stepca-main" "ldap-main"]; 

        # Some services may require persistent storage. Declare here which volume on the host should be used.
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
        services = ["pg-main"]; 
      };
      apps = {
        host = "cpuhost1";
        vcpu = 8;
        memory = 16000;
        ip = "192.168.1.203";
        containers = ["nc-main" "git-main"];  # Services can also run within NixOS containers
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


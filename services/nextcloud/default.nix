{flakeRoot, inputs, config, lib, pkgs, topology, path, ... }:

# https://danubedata.ro/blog/nextcloud-s3-compatible-primary-storage-2026

let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};
    domain = topology.domain;
    hostname = "nextcloud.${domain}";
in {

    config = 
    {
        networking.firewall.allowedTCPPorts = [443 80];
        services.nextcloud = {
            enable = true;	
            #https = true; /*IMPORTANT IF HTTPS*/
            home = "/var/lib/nextcloud";
            hostName = "nextcloud.${domain}";
            #phpPackage = lib.mkForce (pkgs.php83.withExtensions ({ all, enabled }: enabled ++ [ all.smbclient ]));

            maxUploadSize = "100G";

            config.adminuser = "admin";
            config.adminpassFile = "/var/lib/secrets/nextcloud-admin.key";
            config.dbtype = "pgsql";
            config.dbhost = "postgres.${domain}:5432";
            config.dbuser = "nextcloud";
            config.dbpassFile = "/var/lib/secrets/db-nextcloud.key";
            
            occ = ["user:report"];

            phpOptions = {
                upload_max_filesize = "100G";
                post_max_size = "100G";
                max_execution_time = 3600;
                max_input_time = 3600;
                output_buffering = 0;
                #memory_limit = "5G";
                "opcache.enable" = 1;
                "opcache.memory_consumption" = 128;
                "opcache.interned_strings_buffer" = 16;
                "opcache.max_accelerated_files" = 10000;
                "opcache.revalidate_freq" = 1;
                "opcache.save_comments" = 1;
            };
            settings = {
                #loglevel = 1;
                #log_type = "file";
                maintenance_window_start = 0;
                maintenance_window_end = 3;
                trusted_domains = [
                    "nextcloud.${domain}"	
                ];
                trusted_proxies = [
                    #"162.38.243.60"
                    topology.vmSubnet
                    "192.168.100.0" #containers proxy TODO
                    
                ];
                overwritehost = hostname;
                #overwriteprotocol = "https";
            };
            config.objectstore.s3 = {
                  enable = true;
                  bucket = "nextcloud";
                  region = "garage";
                  #autocreate = true;
                  verify_bucket_exists = true;
                  key = builtins.readFile "${path}/.secrets/git/s3-nextcloud.id"; #Key ID #TODO
                  secretFile = "/var/lib/secrets/s3-nextcloud.key";

                  hostname = "s3.${domain}";
                  useSsl = true;
                  port = 443;
                  usePathStyle = true;
            };

            caching.memcached = true;
            caching.redis = true;
            configureRedis = true;
        };

        systemd.services.nextcloud-setup = {
            environment = {
                PGSSLMODE = "require";
            };
        };
    };

}

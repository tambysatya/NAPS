{flakeRoot, lib, inputs, config, ...}:

let
  utils = import "${flakeRoot}/lib" {inherit inputs lib;};
  generateHost = hostName: hostconf: { # generates a single host
      provider.libvirt = [{
        uri = "qemu+ssh://root@${hostconf.ipAddress}/system"; 
        alias = hostName;
      }];
      resource.libvirt_pool = {
        "iso_${hostName}" = {
          name = "iso";
          type = "dir";
          target.path = "/var/lib/libvirt/iso";
          provider = "libvirt.${hostName}";
        };
        "default_${hostName}" = {
          name = "qcow";
          type = "dir";
          target.path = "/var/lib/libvirt/qcow/terranix";
          provider = "libvirt.${hostName}";
        };
      };
    resource.libvirt_volume."iso_${hostName}" = {
      name = "nixos-autoinstall.iso";
      pool = "\${resource.libvirt_pool.iso_${hostName}.name}";
      create.content.url = "bootstrap.iso";
      provider = "libvirt.${hostName}";
    };


  };
in {
    naps.outputs.domains = utils.mergeAll (lib.mapAttrsToList generateHost config.naps.topology.hosts);
}




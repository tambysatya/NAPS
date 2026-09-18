{flakeRoot, lib,inputs, config, ...}:

let
  utils = import "${flakeRoot}/lib" {inherit lib inputs;};
  generateVMDomain = vmname: vmconf:
      let token = builtins.readFile ".secrets/tokens/${vmname}.token";
          host = vmconf.host;
      in 
        {
             resource.libvirt_domain."${vmname}" = {
                provider = "libvirt.${host}";
                autostart = true;
                running = true; #starts the vm
                sys_info = [
                  {smbios = {
                    system = {
                        entry = [
                            {name = "serial"; value = vmconf.ip;}
                        ];};
                    #chassis = {entry = [{name = "serial"; value = token;}];}; #need to be added purely (maybe using an app)
                    chassis = {
                        entry = [
                            {name = "serial"; value = "${lib.toUpper vmname}_TOKEN";}
                        ];
                    };  # TO REPLACE WITH SED
                    bios = {
                        entry = [
                            {name = "vendor"; value = vmconf.gateway;}
                        ];
                    }; 
                    };
                  }
                ];
                name = vmname;
                type="kvm";

                memory = vmconf.memory;
                memory_unit = "MiB";
                vcpu = vmconf.vcpu;
                cpu.mode = "host-passthrough";

                features.acpi = true;
                os = {
                  type = "hvm";
                  boot_devices = [{dev="hd";} {dev = "cdrom";}];
                  type_machine = "q35";
                  firmware = "efi";
                  sm_bios.mode = "sysinfo";
                };
                devices = {
                  interfaces = [
                    {
                      source.bridge.bridge= vmconf.bridge;
                      model.type = "virtio";
                    }
                  ];
                  serials = [
                  {
                    type="pty";
                    source = {path="/dev/pts/0";};
                    target = {type="isa-serial"; port=0;};
                  }
                  ];
                  consoles = [{
                    type = "pty";
                    source = {path = "/dev/pts/0";};
                    target = {type="serial"; port=0;};
                  }
                  ];
                };
              };
          };
in {
    naps.outputs.domains = utils.mergeAll (lib.mapAttrsToList generateVMDomain config.naps.topology.vms);
}

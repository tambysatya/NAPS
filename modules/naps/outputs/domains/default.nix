{lib,inputs, config, ...}:

let 
    provider = 
        {
          terraform.required_providers.libvirt = {
            source = "dmacvicar/libvirt";
          };
        };


in {
    imports = [
        ./hosts.nix
        ./vms.nix
        ./volumes.nix
    ];
    naps.outputs.domains = provider;
}

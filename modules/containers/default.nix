{flakeRoot, lib, inputs, pkgs, config, topology, deploy, vmname, extraArgs, ...}:
{
    config.containers = lib.genAttrs topology.vms.${vmname}.containers (name: {specialArgs = extraArgs;} );
}

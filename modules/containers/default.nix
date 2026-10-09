{flakeRoot, lib, inputs, pkgs, config, naps, vmname, extraArgs, ...}:
{
    config.containers = lib.genAttrs naps.topology.vms.${vmname}.containers (name: {specialArgs = extraArgs // {inherit naps flakeRoot; vmname=name;};} );
}

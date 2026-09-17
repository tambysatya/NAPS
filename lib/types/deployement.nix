{lib, inputs,...}:
let
    types = lib.types;
    vmname = types.str;
in rec {
    deployementTag = types.enum ["test"]; #TODO check if there is only one primary across the napsstructure


    container = types.submodule  {
        options = {
            container = lib.mkOption {
                description = "Name of the container";
                type = types.str;
            };
            vm = lib.mkOption {
                description = "Name of the hosting virtual machine";
                type = types.str; # TODO check if exists
            };
        };
    };
    deployementHostType = types.enum ["vm" "container"];
    deployementHost = types.either vmname container;


    deployementEnvironment = types.submodule {
        options = {
            type = lib.mkOption {
                description = "Type of deployement: container or nixos";
                type = deployementHostType;
            };
            host = lib.mkOption {
                description = "Which environment hosts the service";
                type = deployementHost;
            };
            priority = lib.mkOption{
                description = "Max priority is the primary";
                type = types.int;
                default = 100;
            };
            tags = lib.mkOption {
                description = "Specific tags to trigger specific behvavior";
                type = types.listOf (types.oneOf [deployementTag types.str]);
                default = [];
            };
        };
    };

}

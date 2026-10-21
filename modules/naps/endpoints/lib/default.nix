{flakeRoot, lib, inputs,...}:

let

    utils = import "${flakeRoot}/lib" {inherit lib inputs;};


    /* Getters */
    hostsOf = hosts: epname: hosts.${epname};

    /* Predicates on endpoints */

    # True if the endpoint is hosted natively (i.e. not within a container) on the specified vm
    hostedNativelyOn =
        vmname: hosts: epname: 
        lib.filterAttrs (_: ins: utils.envUID (utils.systemEnv ins) == vmname) hosts.${epname} != {};

in 

utils // {

    /* Getters */
    inherit hostsOf; 

    /* Predicates */
    inherit hostedNativelyOn;
}

{lib,inputs, ...}:
let 
    types = lib.types;
in
{

    user = types.submodule {
        options = {
            service = lib.mkOption {
                description = "Service requesting this user";
                type = types.str;
            };
            uid = lib.mkOption {
                description = "Identifier of the user. A group will be created with the same ID";
                type = types.ints.positive;
            };
        };
    };

}

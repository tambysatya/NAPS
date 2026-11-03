{flakeRoot, lib, inputs,...}:

let utils = import "${flakeRoot}/lib" {inherit lib inputs flakeRoot;};

in utils // {

}

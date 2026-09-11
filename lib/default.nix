{lib, inputs, ...}:

let 
    types = lib.types // (import ./lib/types {inherit lib inputs;});

    vars = import ./vars.nix {inherit lib inputs;};

    # Retrieve the AGE Unique Identifier of a  component

    merge = path: a: b:
      if lib.isList a && lib.isList b then
        a ++ b
      else if lib.isAttrs a && lib.isAttrs b then #browses a, check if each value is present in b and merge them
        lib.mapAttrs (name: value:
          if builtins.hasAttr name b then
            merge "${path}.${name}" value b.${name}
          else
            value
        )
        a 
        // (builtins.removeAttrs b (builtins.attrNames a)) # we concat to b since the fields shared by a and b are now in the term.
      else if a == b then a
      else
        throw "Merge: clash during mergeAll: ${path}: ${builtins.toJSON a} and ${builtins.toJSON b}";
    pathToMountUnit = path:
      if path == "/" then
        "-.mount"
      else
        "${(lib.replaceStrings [ "/" ] [ "-" ] (lib.removePrefix "/" path))}.mount";

    mergeAll = listOfAttrsets: lib.foldl' (merge "") {} listOfAttrsets;
    hasDupplicate = l: builtins.length (lib.unique l) == builtins.length l;
    getFirstDupplicate = xs: #returns the first dupplicate or returns null
        let go = seen: rest:
                if rest == []
                then null
                else 
                    let x = builtins.head rest;
                    in if builtins.elem x seen
                       then x
                       else go (seen ++ [x]) (builtins.tail rest);
        in go [] xs;

    partitionAttrs = 
        predicate: attrs:
        let
            f = acc: name:
                let val = attrs.${name};
                    right = acc.right;
                    wrong = acc.wrong;
                in if predicate name val
                   then {right = right // {${name} = val;}; inherit wrong;}
                   else {wrong = wrong // {${name} = val;}; inherit right;};
        in lib.foldl' f {right={}; wrong={};} (builtins.attrNames attrs);

    concatMapAttrsStringsSep = 
        sep: f: attrs: lib.concatStringsSep sep (lib.mapAttrsToList f attrs);

    serviceName = config: id:
        config.infra.topology.services.${id}.is;
    servicePriority = config: id:
        config.infra.topology.services.${id}.priority;
    serviceTags = config: id:
        config.infra.topology.services.${id}.tags;
    serviceInfo = config: id:
        let srvname = serviceName config id;
        in config.infra.services.${srvname};

in vars // {
    inherit partitionAttrs concatMapAttrsStringsSep;
    inherit mergeAll pathToMountUnit;
    inherit hasDupplicate getFirstDupplicate;
    inherit serviceName servicePriority serviceTags serviceInfo;
}

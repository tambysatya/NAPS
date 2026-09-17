{inputs, lib, naps, pkgs, ...}:

let

    gen = import ./lib {inherit inputs lib pkgs naps;};

    generateNodes =
        lib.concatStringsSep "\n" (lib.mapAttrsToList gen.generateServiceNodes naps.services);
    generateEdges =
        lib.concatStringsSep "\n" (lib.mapAttrsToList gen.generateServiceEdges naps.services);

    code = pkgs.writeText ".graph.dot"
           ''
            digraph naps {
                rankdir = "LR";
                ${generateNodes}
                ${generateEdges}
            }
           '';

in
{
    main = pkgs.writeShellApplication {
            name = "visualization";
            runtimeInputs = [
                pkgs.graphviz
            ];
            #dummy
            text = ''
                ${pkgs.graphviz}/bin/dot -Tsvg ${code} -o naps.svg
            '';
           };
}

{lib, inputs, config, ...}:

let

in {
    imports = [
        ./assets.nix
        ./endpoints.nix
    ];
}

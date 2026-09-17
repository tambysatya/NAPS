{inputs, lib, naps,...}:
let
    register = import ./register.nix {inherit inputs lib naps;};
in {
    inherit (register) registerSecret registerCertificate registerEndpoints registerDBAccess registerS3Access registerVolume registerUser;
}

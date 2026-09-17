
{inputs, lib, path,...}:
/* Default configuration on all machines */
let
in {
	imports = [
		   ../services/packages.nix # default packages installed system-wide
    ];

	nix.settings.experimental-features = ["nix-command" "flakes"]; #enable flakes
	security.pki.certificateFiles = [
                                        "${path}/.secrets/git/root_ca.crt"
                                        "${path}/.secrets/git/intermediate_ca.crt"
                                    ]; #trust the root-ca
	#environment.etc."root_ca.crt".text = builtins.readFile "${naps.flakePath}/${vars.git}/root_ca.crt";
	#environment.etc."intermediate_ca.crt".text = builtins.readFile "${naps.flakePath}/${vars.git}/intermediate_ca.crt";
	programs.vim = {
		enable = true;
		defaultEditor = true;
	};

    #systemd.network.enable = true;
    #networking.useNetworkd = true;


}

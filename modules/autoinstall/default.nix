{inputs, config, lib, pkgs, path, naps, ...}:

/* Reads product_serial to identify which flakes to be deployed */


let 
    installer = pkgs.writeShellApplication {
			name = "autoinstall";
			runtimeInputs = with pkgs; [
						git nix util-linux nixos-install-tools
						inputs.disko.packages.${pkgs.system}.disko
						curl gzip gnutar
					];
			text = ''
				#!${pkgs.bash}/bin/bash
				set -euo pipefail


				IP=$(cat /sys/class/dmi/id/product_serial)
				GW=$(cat /sys/class/dmi/id/bios_vendor)
				TOKEN=$(cat /sys/class/dmi/id/chassis_serial)

                echo "Configuring the network"
                IFACE="enp1s0"
                ip addr add "$IP" dev "$IFACE"
                ip link set "$IFACE" up
                ip route add default via "$GW" dev "$IFACE"


				echo "Partitioning...."

				set -x
				
				#printf 'yes\n' | disko --mode destroy  --flake "/etc/nixos#$HOST"
				disko --mode format,mount --yes-wipe-all-disks --flake "/etc/nixos#$HOST"
				#disko --mode destroy,format,mount --yes-wipe-all-disks --flake "/etc/nixos#$HOST"
				set +x

				echo "Downloading the secrets"
				set -x
				curl --cacert /etc/nixos/.secrets/git/root_ca.crt "https://${naps.topology.provisionerAddr}:8080/$TOKEN.tar.gz" > /tmp/"$TOKEN".tar.gz
                tar -xvf /tmp/"$TOKEN".tar.gz -C /tmp

				HOST=$(cat /tmp/FLAKE)
				echo "Deploying $HOST configuration"
                nix run /etc/nixos#install-secrets-"$HOST" /tmp

                

				mkdir -p /mnt/var/lib/step-ca/certs/
				chmod 0755 /mnt/var/lib/step-ca/
				chmod 0755 /mnt/var/lib/step-ca/certs

				echo "Installing $HOST..."
				${config.system.build.nixos-install}/bin/nixos-install --flake "/etc/nixos#$HOST"

				
				systemctl --no-block reboot
				'';
		};
in {
	systemd.services.autoinstall = {
		wantedBy = ["multi-user.target"];
		after = ["network-online.target"];
		wants = ["network-online.target"];
		serviceConfig = {
			User = "root";
			Type = "oneshot";
			ExecStart = "${installer}/bin/autoinstall";
		};
	};
}

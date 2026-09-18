{inputs, config, lib, pkgs, path, naps, ...}:

/* Reads product_serial to identify which flakes to be deployed */


let 
    setip = pkgs.writeShellApplication {
			name = "setip";
			runtimeInputs = with pkgs; [
                        iproute2
					];
			text = ''
				#!${pkgs.bash}/bin/bash
				set -euo pipefail


				IP=$(cat /sys/class/dmi/id/product_serial)
				GW=$(cat /sys/class/dmi/id/bios_vendor)

                echo "Configuring the network"
                IFACE="enp1s0"
                ${pkgs.iproute2}/bin/ip addr add "$IP/24" dev "$IFACE"
                ${pkgs.iproute2}/bin/ip link set "$IFACE" up
                ${pkgs.iproute2}/bin/ip route add default via "$GW" dev "$IFACE"

				'';
		};
    installer = pkgs.writeShellApplication {
			name = "autoinstall";
			runtimeInputs = with pkgs; [
						git nix util-linux nixos-install-tools
						inputs.disko.packages.${pkgs.system}.disko
						curl gzip gnutar
                        iproute2
					];
			text = ''
				#!${pkgs.bash}/bin/bash

				set -euo pipefail
				echo "Downloading the secrets"
				TOKEN=$(cat /sys/class/dmi/id/chassis_serial)
                URL="https://${naps.topology.provisionerHost}:8080/$TOKEN.tar.gz"
				set -x
				#curl --cacert /etc/nixos/.secrets/git/root_ca.crt "https://${naps.topology.provisionerHost}:8080/$TOKEN.tar.gz" > /tmp/"$TOKEN".tar.gz
                until curl --cacert /etc/nixos/.secrets/git/root_ca.crt "$URL" > /tmp/"$TOKEN".tar.gz; do
                    echo "${naps.topology.provisionerHost} not reachable..."
                    sleep 1
                done
                tar -xvf /tmp/"$TOKEN".tar.gz -C /tmp

				HOST=$(cat /tmp/FLAKE)


				echo "Partitioning...."

				set -x
				
				#printf 'yes\n' | disko --mode destroy  --flake "/etc/nixos#$HOST"
				disko --mode format,mount --yes-wipe-all-disks --flake "/etc/nixos#$HOST"
				#disko --mode destroy,format,mount --yes-wipe-all-disks --flake "/etc/nixos#$HOST"
				set +x

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
	systemd.services.setip = {
		wantedBy = ["multi-user.target"];
		after = ["network-pre.target"];
		requires = ["network-pre.target"];
		serviceConfig = {
			User = "root";
			Type = "oneshot";
			ExecStart = "${setip}/bin/setip";
		};
	};
	systemd.services.autoinstall = {
		wantedBy = ["multi-user.target"];
		after = ["network-online.target" "setip.service"];
		requires = ["network.target" "setip.service"];
		serviceConfig = {
			User = "root";
			Type = "oneshot";
			ExecStart = "${installer}/bin/autoinstall";
		};
	};
}

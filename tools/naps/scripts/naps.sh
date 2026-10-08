
naps_plan(){
    print_vms "$(red DESTROY:)" "$DESTROYED_VMS"
    print_vms "$(green NEW:)" "$NEW_VMS"
    print_vms "$(blue REBUILD:)" "$REBUILT_VMS"
}

naps_usage(){
    cat <<-EOF
	Usage: naps <command>

	Commands:
		init: initializes an infrastructure using a standard template
		plan: Show infrastructure changes
		apply: Deploy infrastrucure

	It is possible to perform a specific task of the deployement using the following commands:
		check: checks if the infrastructure is coherent
		build <assets|domains|iso>: Generates the assets, terraform domains or self-install iso
		provisioner <upload|run>: Uploads the secrets on the provisioning server or starts the services
		deploy [tofu| rebuild]: Deploys the terraform or the nixos config (both if empty)
	EOF
}



DRY_RUN="${DRY_RUN:-false}"

run_local(){
    if $DRY_RUN; then
        printf '+'
        printf ' %q' "$@"
        printf "\n"
	else 
		"$@"
    fi
}

# shellcheck disable=SC2029
run() {
    if $DRY_RUN; then
        printf '+'
		if [[ -n "$SSH" ]]; then
			printf "%s" " ssh $SSH bash"
		fi
        printf ' %q' "$@"
        printf "\n"
    elif [[ -n "$SSH" ]]; then
		ssh "$SSH" "$@"
	else 
		"$@"
    fi
}

# shellcheck disable=SC2120
run_script() {
    if $DRY_RUN; then
		if [[ -n "$SSH" ]]; then
			echo "ssh $SSH bash <<-EOF"
		fi
		cat "$@"
		if [[ -n "$SSH" ]]; then
			echo "EOF"
		fi
    elif [[ -n "$SSH" ]]; then
		ssh "$SSH" bash
	else 
		bash
    fi
}

naps_build(){
    case "${1:-}" in
        assets)
            run_local nix run .#gen-assets
            ;;
        domains)
            run_local nix run .#build-domains
            ;;
        iso)
			run_local git add .secrets/git
            run_local nix build .#nixosConfigurations.iso.config.system.build.isoImage
            ;;
        *)
            naps_build assets
            naps_build iso
            naps_build domains
        ;;
    esac
}

naps_provisioner(){

    case "${1:-}" in
        run)

			yellow "$(bold "+ Install/Update the secret provisioner $SSH...")"
			# shellcheck disable=SC2119,2154,2029
		    run_script <<-EOF
				mkdir -p ~/.confg/systemd/user
				nix build --refresh github:tambysatya/NAPS#provisioner-services
				for service in result/*.service; do
				    ln -sf "\$(readlink -f "\$service")" "\$HOME/.config/systemd/user/\$(basename "\$service")"
				done
				systemctl --user daemon-reload
				systemctl --user restart provisioner-tokens.service
				systemctl --user restart provisioner-mtls.service
				EOF
            ;;
        upload)
                yellow "$(bold "+ Uploading secrets to $SSH ...")"
                run install -d -m 0700 .local/naps && rm -rf .local/naps/*
				if [[ -n "$SSH" ]]; then
					run_local scp -r .secrets/provisioner "$SSH:.local/naps/"
				fi
            ;;
        *)
            naps_provisioner upload
            naps_provisioner run
			;;
    esac
}

naps_deploy(){
	case "${1:-}" in
        tofu)
			shift
            run_local tofu apply 
            ;;
        rebuild)
            for vm in $REBUILT_VMS; do
                run_local nixos-rebuild switch --flake .#"$vm" --target-host root@"$vm"
            done
            ;;
        *)
            naps_deploy tofu 
            naps_deploy rebuild

			;;
    esac
}

naps_apply(){

	naps_plan 

	yellow "$(bold "Building...")"
	naps_build "$@"

	yellow "$(bold "Provisioning...")"
	naps_provisioner "$@"

	yellow "$(bold "Deploying...")"
	naps_deploy 

}


if [[ "$1" == "init" ]]; then
	bold "Initializing a naps project"
	nix flake init -t github:tambysatya/NAPS 
	tofu init
	git init
	git add flake.nix inventory.nix
	exit 0
elif [[ "$1" == "help" || "$1" == "-h" || "$1" == "--help" ]]; then
	naps_usage
	exit 0
fi

SSH=$(nix eval .#naps.topology.provisioner.ssh --json | jq -r '. // empty')
ALL_VMS=$(nix eval .#naps.topology.vms --json | jq -r 'keys[]' | sort)

VM_DEPLOYED=""
if [[ -e "terraform.tfstate" ]]; then
	VM_DEPLOYED=$(tofu state list |  sed -n 's/libvirt_domain.//p' | sort)
fi

NEW_VMS=$(comm -23 \
    <(printf '%s\n' "$ALL_VMS") \
    <(printf '%s\n' "$VM_DEPLOYED"))
DESTROYED_VMS=$(comm -13 \
    <(printf '%s\n' "$ALL_VMS") \
    <(printf '%s\n' "$VM_DEPLOYED"))
REBUILT_VMS=$(comm -12 \
    <(printf '%s\n' "$ALL_VMS") \
    <(printf '%s\n' "$VM_DEPLOYED"))


case "${1:-}" in
    -h | help)
        naps_usage
        ;;
	check)
		shift
		nix flake check
		;;
    plan)
        shift
        naps_plan
        ;;
	apply)
		shift
		naps_apply "$@"
		;;
    build)
        shift
        naps_build "$@"
        ;;
    deploy)
        shift
        naps_deploy "$@"
        ;;
    provisioner)
        shift
        naps_provisioner "$@"
        ;;

    *)
        echo "Unknown command: $1" >&2
        echo
        naps_usage
        exit 1
        ;;
esac

exit 0

##### CONFIRM ?


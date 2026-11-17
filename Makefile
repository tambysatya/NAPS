
.ONESHELL:
SHELL := $(shell which bash)


phase1:
	nix eval --impure path:.#debugPhase1 --json  | jq -C
	
test:
	nix eval --impure path:.#debugPhase2.identity.config.sops.secrets --json  | jq -C

iso :
	 [ -f bootstrap.iso ] && rm -f bootstrap.iso
	 nix build --impure path:.#nixosConfigurations.iso.config.system.build.isoImage
	 cp result/iso/*.iso bootstrap.iso


mount:
	# mounts the vm-provisioning repo
	sshfs vm-provisioning:git/secrets-provisioner/ssl secrets/plain/certs
	sshfs vm-provisioning:git/secrets-provisioner/tokens tokens
gen-secrets:
	nix run .#gen-secrets
terranix:
	nix build --impure .#terranix -o test.tf.json
deploy :

	 ./scripts/bootstrap-secrets.sh
	 export TOKEN_identity=$$(openssl rand -hex 32)
	 export TOKEN_storage=$$(openssl rand -hex 32)
	 export TOKEN_postgres=$$(openssl rand -hex 32)
	 export TOKEN_apps=$$(openssl rand -hex 32)

	 cp secrets/age/apps.key tokens/apps$$TOKEN_apps
	 cp secrets/age/storage.key tokens/storage$$TOKEN_storage
	 cp secrets/age/postgres.key tokens/postgres$$TOKEN_postgres
	 cp secrets/age/identity.key tokens/identity$$TOKEN_identity

	 nix build --impure path:.#terranixConfigurations -o test.tf.json 


iso:

	 [ -f bootstrap.iso ] && rm -f bootstrap.iso
	 nix build  .#nixosConfigurations.iso.config.system.build.isoImage
	 cp result/iso/*.iso bootstrap.iso

apps:

	nix build .#nixosConfigurations.apps.config.system.build.toplevel

doc:
	nix build .#options-doc


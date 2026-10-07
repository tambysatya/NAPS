ALL_VMS=$(nix eval .#naps.topology.vms --json | jq -r 'keys[]' | sort)
VM_DEPLOYED=$(tofu state list | grep 'libvirt_domain' | sed 's/libvirt_domain.//' | sort)

NEW_VMS=$(comm -23 \
    <(printf '%s\n' "$ALL_VMS") \
    <(printf '%s\n' "$VM_DEPLOYED"))
DESTROYED_VMS=$(comm -13 \
    <(printf '%s\n' "$ALL_VMS") \
    <(printf '%s\n' "$VM_DEPLOYED"))
REBUILT_VMS=$(comm -12 \
    <(printf '%s\n' "$ALL_VMS") \
    <(printf '%s\n' "$VM_DEPLOYED"))



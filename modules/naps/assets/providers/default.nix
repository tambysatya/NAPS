{...}:


{
    imports = [
        ./ssl.nix # step-ca tls haproxy
        ./random.nix # random strings: plain, password
        ./nix-store.nix # nix-store + ssh-keygen TODO move ssh
    ];
}

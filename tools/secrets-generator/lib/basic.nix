{lib, inputs, pkgs, path,...}:
let
    utils = import "${inputs.self.outPath}/lib" {inherit lib inputs;};
    generateIdentity = env: ''
        mkdir -p .secrets/perVM/${utils.envHost env}
        echo ${utils.envHost env} > .secrets/perVM/${utils.envHost env}/FLAKE #writes the flake name
    '';
    give = filename: env: 
        let filepath = ".secrets/plain/${filename}";
           # target = if env.type == "vm"
           #          then ".secrets/perVM/${env.host}/${filename}"
           #          else ".secrets/perVM/${env.host.vm}/${env.host.container}/${filename}";
            target = ".secrets/perVM/${utils.envHost env}/${filename}";
        in ''cp ${filepath} ${target}'';

    ship = 
        name:
        let 
            path = ".secrets/perVM";
            provisioner = ".secrets/provisioner/secrets";
            tokens = ".secrets/tokens";
        in ''
            mkdir -p ${provisioner}
            mkdir -p ${tokens}
            tar -cvf ${path}/${name}.tar -C ${path}/${name} .
            ${lib.getExe pkgs.gzip} ${path}/${name}.tar

            TOKEN=$(${lib.getExe pkgs.openssl} rand -hex 64)
            mv ${path}/${name}.tar.gz "${provisioner}/$TOKEN.tar.gz"
            echo "$TOKEN" > "${tokens}/${name}.token"
        '';

    applyToken = 
        terraformConfPath: name:
        let tokenpath = ".secrets/tokens/${name}.token";
        in ''
            TOKEN=$(cat ${tokenpath})
            sed -i "s/${lib.toUpper name}_TOKEN/$TOKEN/" ${terraformConfPath}
        '';
        

in
{
    inherit give generateIdentity ship applyToken;
}

{lib, inputs, config,...}:

let 
    topology = config.naps.topology;
    secrets = {
        names = ["ca-password.key"  "intermediate_ca_key"];
        owner = "step-ca";
        kind = {provider = "step";};
    };
    hostname = "ca.${topology.domain}";
    port = 8443;
in
{
naps.services.step-ca = {
    path = ./.;
    users.step-ca = {service="step-ca"; uid=10006;};
    assets = {
        "step-ca" = {
            provider = "step-ca";
            installArgs = {owner = "step-ca";};
        };
    };
    endpoints.http = [
        {inherit hostname port; tls=false;}
    ];
};
}


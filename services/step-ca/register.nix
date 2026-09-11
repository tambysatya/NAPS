{lib, inputs, config,...}:

let 
    topology = config.infra.topology;
    secrets = {
        names = ["ca-password.key"  "intermediate_ca_key"];
        owner = "step-ca";
        kind = {provider = "step";};
    };
    hostname = "ca.${topology.domain}";
    port = 8443;
in
{
infra.services.step-ca = {
    users = [{name="step-ca"; uid=10006;}];
    endpoints.http = [
        {inherit hostname port; tls=false;}
    ];
};
}


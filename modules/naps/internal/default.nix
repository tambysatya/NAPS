{
    imports = [ 
        ./envs # all the deployement environments
        ./services # internal representations of the services (user declaration decorated with metadata such as the map of deployement environments)
        #./volumes # Summary of the storage allocation (for the migration procedure)

        ./links # Summary of the links
        ./endpoints # Summary of the endpoints
        ./assets # Summary of the assets (for the secrets-generator): depends on ./services and ./links
    ];
}

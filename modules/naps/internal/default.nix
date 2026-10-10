{
    imports = [ 
        ./envs # all the deployement environments
        ./services # internal representations of the services (user declaration decorated with metadata such as the map of deployement environments)
        ./volumes # Summary of the storage allocation (for the migration procedure)

        ./assets # Summary of the assets (for the secrets-generator)
    ];
}

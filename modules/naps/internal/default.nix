{
    imports = [ 
        #./persistent # Summary of the storage allocation (for the migration procedure)

        #./links # Summary of the links
        #./endpoints # Summary of the endpoints
        ./assets # Summary of the assets (for the secrets-generator): depends on ./services and ./links
    ];
}

# Extending NAPS

NAPS provides several intermediate representations in order to extend the libraries of assets providers, network configuration and services dependencies across the infrastructure (links). Philosophically, NAPS manages internally the buisness logic while these libraries provides differents backends for the technical logic. 

Each of these modules has several `inputs` and generates one or multiple `intermediate representations`. Backend libraries essentially provide `callbacks` and `types` describing additional user-defined inputs allowing naps to compute the outputs required by the buisness logic.

Inputs of each module are filled to `naps.inputs.*`, where diverse runtimes checks are performed, including the typechecking.

Backends, including user-defined backends are provided to `naps.lib.*`. We now describe how to add new ones.


## New assets providers

The asset module automatically produces a script to generate all the assets of the infrastructure, and dispatch them to the corresponding virtual machines. As an example, we describe here how the `tls` asset provider is written.

Any asset provider consists in two functions: a `generator` and an `installer`. The `generator` produces a script that will be added to the global asset-generator script while the `installer` produces a script that will be runned on the machines owning the asset in order to install them on the right place.

### ShippedAsset

The fundamental structure is the `ShippedAsset` type, corresponding to a tuple `{asset : Asset, recipients : [EnvUID] }`.

`Asset = {generateArgs, installArgs, reload}` is a structure containing all the informations that are passed to the `generator` and `installer` functions, as well as the list of services depending on this asset (the names comes from the fact that this field describes which services should be reloaded whenever the asset changes).


## New endpoints types

## New links

## Persistence backends

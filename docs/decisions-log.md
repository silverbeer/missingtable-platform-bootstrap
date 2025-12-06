What variables and outputs are for?
    Variables makes the resources resuable.  Otherwise they need to be hardcoded.  Adding a sensible to the variable makes sense.

    Outputs provide important details or outputs from executing the resource.   For example if you create an ec2 instance you will be able to output key information about the newly created ec2 resource like instance ID or ip address

The plan vs apply distinction?

    plan is the dry run
    apply is the real run, changes will be made

    It's best practice to always run plan ahead of apply.  This should be forced or built into any tofu pipelines we create

What you learned about providers, init, the lock file

    providers have versions.  This syntax will deploy the latest stable version - version = "~> 5.0".  There is a tofu lock file that gets commited that will track the exact version deployed.  Other uses of the repo will be locked to this version due to the lock file. 

    AWS provider is big.  initial tofu init will take some time

tofu destroy is good to use while learning to be a ninja.  Good practice - this will safe us money down the road when we start spinning up EKS.
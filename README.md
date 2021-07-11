# doenet.cloud devops scripts

To make it easier to deploy doenet.cloud, the included `doenet.nix`
can be used.  Note that `doenet.nix` references other `doenet.cloud`
repos, so you will need to have the `doenet-api` and `doenet-id` repo
checked out as well.

Then run
```
nixops create -d doenet doenet.nix
nixops deploy -d doenet
```
to deploy `doenet.cloud` to AWS.



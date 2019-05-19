# EC2 workshop host

This is a scrappy host for a disposable EC2 development / utility machine.
It's part of an experiment to see how viable the iPad Pro is for actually getting work done.

It's defined by terraform in the `tf/` directory.

```
cd tf
terraform init
terraform plan
terraform apply
```

Currently it installs a handful of helpful tools -- and docker. The concept is to have docker end up being the way most tools/apps are installed. Check out `tf/user_data.sh` for the details.

At the moment there is no firewall, I'm considering different ways to beef that up, but SSH by default is key only.

One notable feature is an EBS volume (currently 20GB) which is mounted at `/workspace`. It's tagged, so if the host is recreated, it's attached to the new one. This allows cheaply rebuilding the 'main' host while not requiring re-cloning all repos and work in progress.



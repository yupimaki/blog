# Terraform secret variables

Place secret variables in a file called `terraform.tfvars` which will be sourced on running `terraform <command>`.

As `terraform/variables.tf` declare variables without defaults, if they are not provided in the `terraform.tfvars` file, they will be asked for at run time.

Hence, so far we need to add

```
access_key = "AKIAXXXXXXXXXXXXXXXX"
secret_key = "XXXXXXXxxXxxxXxXxXXxxXxxxXxxxXxxXxxxxXXx"
public_key = "ssh-rsa AAAAB3N...THISISAREALLYLONGSTRING...DPMDMPDOPWJEF"
region = "us-east-1"
```

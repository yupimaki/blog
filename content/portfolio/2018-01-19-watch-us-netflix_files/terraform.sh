#!/bin/bash
terraform $1 -var-file secrets/terraform.tfvars

# Best practices for terraform

* [AWS](./aws/README.md)
* [Azure](./azure/README.md)


Terraform Best Practices for Cloud users.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  
- [Run terraform command with var-file](#run-terraform-command-with-var-file)
- [Manage remote backend for tfstate files](#manage-remote-backend-for-tfstate-files)
- [Manage multiple Terraform modules and environments easily with Terragrunt](#manage-multiple-terraform-modules-and-environments-easily-with-terragrunt)
- [Visualize Tf resource configuration or execution plan using the Tf Graph](#visualize-tf-resource-configuration-or-execution-plan-using-the-tf-graph)
<!-- END doctoc generated TOC please keep comment here to allow auto update -->

>the READM for terraform version 0.11 and less has been renamed to [README.0.11.md](README.0.11.md)

## Run terraform command with var-file

```
$ cat config/dev.tfvars

name = "dev-stack"
tag_team_name = "hello-world"
 
$ terraform plan -var-file=config/dev.tfvars
```

With `var-file`, you can easily manage environment (dev/stag/uat/prod) variables.

With `var-file`, you avoid running terraform with long list of key-value pairs ( `-var foo=bar` )

## Manage remote backend for tfstate files

Terraform doesn't support [Interpolated variables in terraform backend config](https://github.com/hashicorp/terraform/pull/12067), normally you write a seperate script to define a backend storage name for different environments, but I recommend to hard code it.

* [Remote Backend - AWS S3](aws/README.me#manage-s3-backend-for-tfstate-files)
* [Remote Backend - Azure Blob Storage](azure/README.md#manage-blob-storage-backend-for-tfstate-files)


## Manage multiple Terraform modules and environments easily with Terragrunt

Terragrunt is a thin wrapper for Terraform that provides extra tools for working with multiple Terraform modules. https://www.gruntwork.io
- [Terragrunt - AWS QuickStart](aws/README.md#manage-multiple-terraform-modules-and-environments-easily-with-terragrunt)
- Terragrunt - Azure QuickStart - Coming Soon

## Visualize Tf resource configuration or execution plan using the Tf Graph

the Graph is great tool to visualize resource dependencies especially useful for complex Tf configurations -  [get started here](./azure/GraphTypePlan.md)

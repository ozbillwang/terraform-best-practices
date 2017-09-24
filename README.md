# terraform-best-practices

Terraform Best Practices for AWS users.

* [Run terraform command with var-file](#run-terraform-command-with-var-file)
* [Manage s3 backend for tfstate files](#manage-s3-backend-for-tfstate-files)
* [Retrieves state meta data from a remote backend](#retrieves-state-meta-data-from-a-remote-backend)
* [Use share modules](#use-share-modules)
* [Isolate environment](#isolate-environment)
* [Use terraform import to include as more resources you can](#use-terraform-import-to-include-as-more-resources-you-can)
* [Avoid hard code the resources](#avoid-hard-code-the-resources)
* [Format terraform codes](#format-terraform-codes)
* [Enable version control on terraform state files bucket](#enable-version-control-on-terraform-state-files-bucket)
* [Generate README for each module about input and output variables](#generate-readme-for-each-module-about-input-and-output-variables)
* [update terraform version](#update-terraform-version)
* [Run terraform from docker container](#run-terraform-from-docker-container)
* [Troubleshooting with messy output](#troubleshooting-with-messy-output)
* [some updates for terraform 0.10.x](#some-updates-for-terraform-0.10.x)
* [Useful documents you should read](#useful-documents-you-should-read)

## Always Run terraform command with var-file

```
$ cat config/dev.tfvars

name = "dev-stack"
s3_terraform_bucket = "dev-stack-terraform"
tag_team_name = "hello-world"
 
$ terraform plan -var-file=config/dev.tfvars
```

With `var-file`, you can easily manage environment (dev/stag/uat/prod) variables.

With `var-file`, you avoid to run terraform with long list of key-value pairs ( `-var foo=bar` )

## Manage s3 backend for tfstate files

Terraform doesn't support [Interpolate variables in terraform backend config](https://github.com/hashicorp/terraform/pull/12067), normally you write a seperate script to define s3 backend bucket name for different environments, but I recommend to hard code it directly as below

Add below codes in terraform configuration files.
```
$ cat main.tf

terraform {
  required_version = "~> 0.10"

  backend "s3" {
    encrypt = true
  }
}
```

Define backend variables for particular environment
```
$ cat config/backend-dev.conf
bucket  = "<unique_bucke_name>-terraform-development"
key     = "development/service-1.tfstate"
region  = "ap-southeast-2"
kms_key_id = "alias/terraform"
dynamodb_table = "terraform-lock"
```

### Notes:

- bucket - s3 bucket name, has to be globally unique.
- key - Set some meanful names for different services and applications, such as vpc.tfstate, application_name.tfstate, etc
- dynamodb_table - optional when you want to enable [State Locking](https://www.terraform.io/docs/state/locking.html)

After you set `config/backend-dev.conf` and `config/dev.tfvars` properly (for each environment). You can easily run terraform as below:

```
env=dev
terraform get -update=true
terraform init -backend-config=config/backend-${env}.conf
terraform plan -var-file=config/dev.tfvars
terraform apply -var-file=config/dev.tfvars
```

## Retrieves state meta data from a remote backend

Normally we have several layers to manage terraform resources. After you create the base resources, such as vpc, security group, subnets, nat gateway. You should refer the states directly from vpc layer.

```
data "terraform_remote_state" "stack" {
  backend = "s3"
  config{
    bucket = "${var.s3_terraform_bucket}"
    key = "${var.stack_name}/terraform.tfstate"
    region="${var.aws_region}"
  }
}
 
# Retrieves the vpc_id and subnet_ids directly from remote backend state files.
resource "aws_xx_xxxx" "main" {
  # ...
  subnet_ids = "${split(",", data.terraform_remote_state.stack.data_subnets)}"
  vpc_id     = "${data.terraform_remote_state.vpc.vpc_id}"
}
```

## Use share modules

Manage terraform resource with shared modules, this will save a lot of coding time. 

### NOTES:

terraform modules don't support `count` parameter currently. You can follow up this ticket for updates: https://github.com/hashicorp/terraform/issues/953

[terraform module usage](https://www.terraform.io/docs/modules/usage.html)

[Terraform community modules](https://github.com/terraform-community-modules)

## Isolate environment

Someone create a security group and share it to all non-prod (dev/qa) environments. Don't do that, create resources with different environment name for each environment.


## Use terraform import to include as more resources you can

Sometimes developers created some resources directly to rush. You need to mark these resource and use terraform import to include them in codes. 

## Avoid hard code the resources

A sample:
```
account_number=“123456789012"
```

The current aws account id or account alias can be input directly via data sources.

```
# The attribute `${data.aws_caller_identity.current.account_id}` will be current account number. 
data "aws_caller_identity" "current" {}

# The attribue `${data.aws_iam_account_alias.current.account_alias}` will be current account alias
# Tips: you can easly use this attribue to create terraform bucket with environment, project name, etc.
data "aws_iam_account_alias" "current" {}
```

Refer: [terraform data sources](https://www.terraform.io/docs/providers/aws/)

## Format terraform codes

Always run `terraform fmt` to format terraform configuration files and make them neatly.

I used below codes in Travis CI pipeline (you can re-use it in any pipelines) to validate and format check the codes before you can merge it to master branch.

      - find . -type f -name "*.tf" -exec dirname {} \;|sort -u | while read m; do (terraform validate -check-variables=false "$m" && echo "√ $m") || exit 1 ; done
      - if [ `terraform fmt | wc -c` -ne 0 ]; then echo "Some terraform files need be formatted, run 'terraform fmt' to fix"; exit 1; fi
      

## Enable version control on terraform state files bucket

Always set backend to s3 and enable version control on this bucket. 

If you'd like to manage terraform state bucket as well, recommend to use this repostory I wrote [tf_aws_tfstate_bucket](https://github.com/BWITS/tf_aws_tfstate_bucket) to create the bucket and replica to other regions automatically. 

## Generate README for each module about input and output variables

You needn't manually manage `USAGE` about input variables and outputs. [terraform-docs](https://github.com/segmentio/terraform-docs) can do this job automatically.

Show the command running on mac before you checkin your codes.
```
$ brew install terraform-docs
$ cd terraform/modules/vpc
$ terraform-docs md . > README.md
```

For details on how to run `terraform-docs`, check this repository: https://github.com/segmentio/terraform-docs

## update terraform version

Hashicorp doesn't have a good qa/build/release process for their software and does not follow semantic versioning rules.

For example, `terraform init` isn't compatible between 0.9 and 0.8. Now they are going to split providers and use "init" to install providers as plugin in coming version 0.10

So recommend to keep updating to latest terraform version

## Run terraform from docker container

Terraform releases official docker containers that you can easly control which version you can run.

Recommend to run terraform docker container, when you set your build job in CI/CD pipeline.

```
TERRAFORM_IMAGE=hashicorp/terraform:0.9.8
TERRAFORM_CMD="docker run -ti --rm -w /app -v ${HOME}/.aws:/root/.aws -v ${HOME}/.ssh:/root/.ssh -v `pwd`:/app $TERRAFORM_IMAGE"
```

## Troubleshooting with messy output

Sometime, you applied the changes several times, the plan output always prompts there are some changes, essepecially in iam policy.  It is hard to troubleshooting the problem with messy json output in one line.

With the tool [terraform-landscape](https://github.com/coinbase/terraform-landscape), it improves Terraform plan output to be easier to read and understand, you can easily find out where is the problem. For details, please go through the project at https://github.com/coinbase/terraform-landscape

## some updates for terraform 0.10.x

After Hashicorp splits terraform providers out of terraform core binary from v0.10.x, you will see errors to complain aws, template, terraform provider version are not installed when run `terraform init`

```
* provider.aws: no suitable version installed
  version requirements: "~> 0.1"
```
Please add below codes to `main.tf`

```
provider "aws" {
  version = "~> 0.1"
  region  = "${var.region}"
}

provider "template" {
  version = "~> 0.1"
}

provider "terraform" {
  version = "~> 0.1"
}
```

## Useful documents you should read

[terraform tips & tricks: loops, if-statements, and gotchas](https://blog.gruntwork.io/terraform-tips-tricks-loops-if-statements-and-gotchas-f739bbae55f9)

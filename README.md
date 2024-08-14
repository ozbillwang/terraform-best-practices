# Terraform Best Practices 🌐

Terraform Best Practices for AWS users.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

  - [Run terraform command with var-file](#run-terraform-command-with-var-file)
  - [Enable version control on terraform state files bucket](#enable-version-control-on-terraform-state-files-bucket)
  - [Manage S3 backend for tfstate files](#manage-s3-backend-for-tfstate-files)
    - [Notes on S3](#notes-on-s3)
  - [Manage multiple Terraform modules and environments easily with Terragrunt](#manage-multiple-terraform-modules-and-environments-easily-with-terragrunt)
  - [layers](#layers)
  - [Retrieve state meta data from a remote backend](#retrieve-state-meta-data-from-a-remote-backend)
  - [When troubleshooting, remember to enable debugging](#when-troubleshooting-remember-to-enable-debugging)
  - [re-use terraform modules to save your coding time](#re-use-terraform-modules-to-save-your-coding-time)
  - [Environment Isolation](#environment-isolation)
  - [Use terraform import to include as many resources as you can](#use-terraform-import-to-include-as-many-resources-as-you-can)
  - [Avoid hard coding the resources](#avoid-hard-coding-the-resources)
  - [Validate and format terraform code](#validate-and-format-terraform-code)
  - [Generate README for each module with input and output variables](#generate-readme-for-each-module-with-input-and-output-variables)
  - [Update terraform version](#update-terraform-version)
  - [Efficient Workspace Management with workspace sub-command](#efficient-workspace-management-with-workspace-sub-command)
  - [Terraform version manager](#terraform-version-manager)
  - [Run terraform in docker container](#run-terraform-in-docker-container)
  - [Run test](#run-test)
  - [Minimum AWS permissions necessary for a Terraform run](#minimum-aws-permissions-necessary-for-a-terraform-run)
  - [Usage of variable "self"](#usage-of-variable-self)
    - [One more use case](#one-more-use-case)
  - [Use pre-installed Terraform plugins](#use-pre-installed-terraform-plugins)
  - [Tips to upgrade to terraform 0.12](#tips-to-upgrade-to-terraform-012)
  - [Tips to upgrade to terraform 0.13+](#tips-to-upgrade-to-terraform-013)
- [Contributing](#contributing)
- [Useful terraform modules](#useful-terraform-modules)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

> The README for terraform version 0.11 and less has been renamed to [README.0.11.md](README.0.11.md)

## Run terraform command with var-file

```bash
$ cat config/dev.tfvars

name = "dev-stack"
s3_terraform_bucket = "dev-stack-terraform"
tag_team_name = "hello-world"

$ terraform plan -var-file=config/dev.tfvars
```

With `var-file`, you can easily manage environment (dev/stag/uat/prod) variables.

With `var-file`, you avoid running terraform with long list of key-value pairs ( `-var foo=bar` )

## Enable version control on terraform state files bucket

Always set backend to s3 and enable version control on this bucket.

[s3-backend](s3-backend) to create s3 bucket and dynamodb table to use as terraform backend.

## Manage S3 backend for tfstate files

Terraform doesn't support [Interpolated variables in terraform backend config](https://github.com/hashicorp/terraform/pull/12067), normally you write a separate script to define s3 backend bucket name for different environments, but I recommend to hard code it directly as below. This way is called [partial configuration](https://www.terraform.io/docs/backends/config.html#partial-configuration).

Add below code in terraform configuration files.

```bash
$ cat main.tf

terraform {
  backend "s3" {
    encrypt = true
  }
}
```

Define backend variables for particular environment

```bash
$ cat config/backend-dev.conf
bucket  = "<account_id>-terraform-states"
key     = "development/service-name.tfstate"
encrypt = true
region  = "ap-southeast-2"
#dynamodb_table = "terraform-lock"
```

### Notes on S3

- `bucket` - existing s3 bucket name. Tips: The s3 bucket has to be globally unique, normally I put account id in its name.
- `key` - Set some meaningful names for different services and applications, such as vpc.tfstate, <application_name>.tfstate, etc
- `dynamodb_table` - optional when you want to enable [State Locking](https://www.terraform.io/docs/state/locking.html)

After you set `config/backend-dev.conf` and `config/dev.tfvars` properly (for each environment). You can easily run terraform as below:

```bash
env=dev
terraform get -update=true
terraform init -reconfigure -backend-config=config/backend-${env}.conf
terraform fmt
terraform validate
terraform plan -var-file=config/${env}.tfvars -out='planfile'

# if above dry-run is fine, run below command to apply the change.
# terraform apply 'planfile'
```

If you encountered any unexpected issues, delete the cache folder, and try again.

```bash
rm -rf .terraform
```

## Manage multiple Terraform modules and environments easily with Terragrunt

Terragrunt is a thin wrapper for Terraform that provides extra tools for working with multiple Terraform modules. <https://www.gruntwork.io>

Sample for reference: <https://github.com/gruntwork-io/terragrunt-infrastructure-live-example>

Its README is too long, if you need a quick start, follow below steps:

```bash
# Install terraform and terragrunt
# Make sure you are in right aws account
$ aws s3 ls
# use terragrunt to deploy
$ git clone https://github.com/gruntwork-io/terragrunt-infrastructure-live-example.git
$ cd terragrunt-infrastructure-live-example
# for example, you want to deploy mysql in stage non-prod at region us-east-1
$ cd non-prod/us-east-1/stage/mysql
$ terragrunt plan
# Confirm everything works
$ terragrunt apply
```

So if you followed the setting in terragrunt properly, you don't need to care about the backend state files and variable file path in different environments, even more, you can run `terragrunt plan-all` to plan all modules together.

## layers

Avoid consolidating everything into a single Terraform module, such as combining network creation with application services. The best practice is to separate them into different modules:

* VPC with subnets, gateways, etc
* App-1 and related resources
* App-2 and related resources
* Database-1

## Retrieve state meta data from a remote backend

Typically, we have several layers for managing Terraform resources, including the network, database, and application layers. Once you've created the essential network resources, like VPC, security groups, subnets, and NAT gateways in the VPC stack, your database and application layers should always reference these resources directly using data source [terraform_remote_state](https://developer.hashicorp.com/terraform/language/state/remote-state-data) .

> Note: Starting from Terraform version 0.12 and beyond, you must include additional outputs to reference the attributes; otherwise, you will receive an error message [Unsupported attribute](https://github.com/hashicorp/terraform/issues/21442)

```terraform
data "terraform_remote_state" "this" {
  backend = "s3"
  config = {
    bucket = var.s3_terraform_bucket
    key    = "${var.environment}/vpc.tfstate"
    region = var.aws_region
  }
}

# Retrieves the vpc_id and subnet_ids directly from remote state files from backend s3 bucket.
resource "aws_xx_xxxx" "this" {
  # ...
  subnet_ids = split(",", data.terraform_remote_state.vpc.outputs.data_subnets)
  vpc_id     = data.terraform_remote_state.this.outputs.vpc_id
}
```

## When troubleshooting, remember to enable debugging

```bash
TF_LOG=DEBUG terraform <command>

# or if you run with terragrunt
TF_LOG=DEBUG terragrunt <command>
```

## re-use terraform modules to save your coding time

Compare to AWS Cloudformation template (CFN), managing Terraform resources with shared modules is one of the best features in Terraform. This approach saves a significant amount of coding time, eliminating the need to reinvent the wheel!

You can start from below links:

- [Terraform module usage](https://www.terraform.io/docs/modules/usage.html)
- [Terraform Module Registry](https://registry.terraform.io/)
- [Terraform aws modules](https://github.com/terraform-aws-modules)

## Environment Isolation

At times, developers may consider creating a security group and sharing it across all non-production (dev/staging/qa) environments. However, it's advisable not to do so. Instead, create distinct resources with unique names for each environment and for each resource

```terraform
variable "application" {
  description = "application name"
  default = "<Replace with your project or application name, preferably using a short name of 3 to 4 letters. This is important because certain resources have name length restrictions>"
}

variable "environment" {
  description = "environment name"
  default = "<replace with environment name, such as dev, stag, qa, svt, prod,etc. Use short name if possible, because certain resources have name length restrictions>"
}

locals {
  name_prefix    = "${var.application}-${var.environment}"
}

resource "<any_resource>" "this" {
  name = "${local.name_prefix}-<resource_name>"
  # ...
}
```

By doing so, you can effortlessly define resources with meaningful and distinct names, and you can replicate the same application stack with minimal changes. For instance, you can update the environment to accommodate development, staging, user acceptance testing (UAT), production, and more."

> Tip: Keep in mind that certain resources have name length restrictions, often less than 24 characters. When defining variables for application and environment names, opt for short names, ideally between 3 to 4 letters.

## Use terraform import to include as many resources as you can

Utilize [terraform import](https://www.terraform.io/docs/import/usage.html) to incorporate as many resources as possible into your Terraform configuration. Occasionally, developers may already manually create resources, and it's essential to identify these resources and bring them into your codebase using the `terraform` import command.

## Avoid hard coding the resources

A sample:

```
account_number="123456789012"
account_alias="mycompany"
region="us-east-2"
```

The current aws account id, account alias and current region can be generated by [data sources](https://www.terraform.io/docs/providers/aws/).

```terraform
# The attribute `${data.aws_caller_identity.this.account_id}` will be current account number.
data "aws_caller_identity" "this" {}

# The attribue `${data.aws_iam_account_alias.this.account_alias}` will be current account alias
data "aws_iam_account_alias" "this" {}

# The attribute `${data.aws_region.this.name}` will be current region
data "aws_region" "this" {}

# Set as [local values](https://www.terraform.io/docs/configuration/locals.html)
locals {
  account_id    = data.aws_caller_identity.this.account_id
  account_alias = data.aws_iam_account_alias.this.account_alias
  region        = data.aws_region.this.name
}
```
Now, you are fine to reference them with varaibles: 

* local.account_id
* local.account_alias
* local.region

## Validate and format terraform code

Always run `terraform fmt` to format terraform configuration files and make them neat before commit the codes.

I used below code in pipeline to validate the codes before you can merge it to master branch.

```yml
script:
  - terraform init -reconfigure
  - terraform validate
```

One more check [tflint](https://github.com/wata727/tflint) you can add

```yml
- find . -type f -name "*.tf" -exec dirname {} \;|sort -u |while read line; do pushd $line; docker run --rm -v $(pwd):/data -t wata727/tflint; popd; done
```

## Generate README for each module with input and output variables

You don't have to manually handle the documentation for input and output variables. A tool called [terraform-docs])https://github.com/terraform-docs/terraform-docs) can automate this task for you

Sample command with `docker run` (so you don't have to install it directly)

```bash
docker run --rm -v $(pwd):/data cytopia/terraform-docs terraform-docs md . > README.md
```

For details on how to run `terraform-docs`, check this repository: <https://github.com/cytopia/docker-terraform-docs>

There is a simple sample for you to start [tf_aws_acme](https://github.com/BWITS/tf_aws_acme), the README is generatd by `terraform-docs`

## Update terraform version

It's advisable to stay updated with the latest Terraform versions.

## Efficient Workspace Management with workspace sub-command
The `terraform workspace select -or-create` command simplifies workspace management by either selecting an existing workspace or creating a new one if it doesn’t exist. Use it like this:

```
terraform workspace select -or-create <workspace-name>
```
This ensures you're always working in the correct workspace. After running the command, verify your active workspace with:

```
terraform workspace show
```

This command helps keep your Terraform environment organized and prevents accidental changes in the wrong environment.

## Terraform version manager

You can manage multiple terraform versions with [tfenv](https://github.com/tfutils/tfenv)

sample commands for mac users.

```bash
# install tfenv
$ brew install tfenv

# install several terraform binary with different versions
$ tfenv install 1.1.9
$ tfenv install 1.2.1
$ tfenv install 0.12.11

# list terraform versions managed by tfenv
$ terraform list

# set the default terraform version
$ terraform use 1.2.1
$ terraform version
```

## Run terraform in docker container

Terraform releases official docker containers that you can easily control which version you can run.

Recommend to run terraform docker container, when you set your build job in CI/CD pipeline.

```bash
# (1) must mount the local folder to /apps in container.
# (2) must mount the aws credentials and ssh config folder in container.
$ TERRAFORM_IMAGE=hashicorp/terraform:0.12.3
$ TERRAFORM_CMD="docker run -ti --rm -w /app -v ${HOME}/.aws:/root/.aws -v ${HOME}/.ssh:/root/.ssh -v `pwd`:/app -w /app ${TERRAFORM_IMAGE}"
${TERRAFORM_CMD} init
${TERRAFORM_CMD} plan
```

Or with `terragrunt` by image [alpine/terragrunt](https://hub.docker.com/r/alpine/terragrunt)

```bash
# (1) must mount the local folder to /apps in container.
# (2) must mount the aws credentials and ssh config folder in container.
$ docker run -ti --rm -v $HOME/.aws:/root/.aws -v ${HOME}/.ssh:/root/.ssh -v `pwd`:/apps alpine/terragrunt:0.12.3 bash
# cd to terragrunt configuration directory, if required.
$ terragrunt plan-all
$ terragrunt apply-all
```

## Run test

Way 1: Recommend to add [awspec](https://github.com/k1LoW/awspec) tests through [kitchen](https://kitchen.ci/) and [kitchen-terraform](https://newcontext-oss.github.io/kitchen-terraform/).
Run test within docker container, you can take reference: [README for terraform awspec container](https://github.com/alpine-docker/bundle-terraform-awspec)

Way 2: [terratest](https://terratest.gruntwork.io/)

Way 3: [terraform test](https://developer.hashicorp.com/terraform/language/tests) This testing framework is available in Terraform **v1.6.0** and later.

## Minimum AWS permissions necessary for a Terraform run

There will be no answer for this. But with below iam policy you can easily get started.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowSpecifics",
      "Action": [
        "lambda:*",
        "apigateway:*",
        "ec2:*",
        "rds:*",
        "s3:*",
        "sns:*",
        "states:*",
        "ssm:*",
        "sqs:*",
        "iam:*",
        "elasticloadbalancing:*",
        "autoscaling:*",
        "cloudwatch:*",
        "cloudfront:*",
        "route53:*",
        "ecr:*",
        "logs:*",
        "ecs:*",
        "application-autoscaling:*",
        "logs:*",
        "events:*",
        "elasticache:*",
        "es:*",
        "kms:*",
        "dynamodb:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Sid": "DenySpecifics",
      "Action": [
        "iam:*User*",
        "iam:*Login*",
        "iam:*Group*",
        "iam:*Provider*",
        "aws-portal:*",
        "budgets:*",
        "config:*",
        "directconnect:*",
        "aws-marketplace:*",
        "aws-marketplace-management:*",
        "ec2:*ReservedInstances*"
      ],
      "Effect": "Deny",
      "Resource": "*"
    }
  ]
}
```

Depending on your company's or project's requirements, you can easily modify the resources in the **Allow** section to specify which Terraform commands should have access, and you can add deny policies in the **Deny** section to restrict permissions that are not needed.

## Usage of variable "self"

Quote from terraform documents:

```log
Attributes of your own resource

The syntax is self.ATTRIBUTE. For example \${self.private_ip} will interpolate that resource's private IP address.

Note: The self.ATTRIBUTE syntax is only allowed and valid within provisioners.
```

### One more use case

```terraform
resource "aws_ecr_repository" "this" {
  name = var.image_name
  provisioner "local-exec" {
    command = "./deploy-image.sh ${self.repository_url} ${var.jenkins_image_name}"
  }
}

variable "jenkins_image_name" {
  default = "mycompany/jenkins"
  description = "Jenkins image name."
}
```

You can easily define ecr image url (`<account_id>.dkr.ecr.<aws_region>.amazonaws.com/<image_name>`) with \${self.repository_url}

Any attributes in this resource can be self referenced by this way.

Reference: <https://github.com/shuaibiyy/terraform-ecs-jenkins/blob/master/docker/main.tf>

## Use pre-installed Terraform plugins

There is a way to use pre-installed Terraform plugins instead of downloading them with `terraform init`, the accepted answer below gives the detail:

[Use pre-installed Terraform plugins instead of downloading them with terraform init](https://stackoverflow.com/questions/50944395/use-pre-installed-terraform-plugins-instead-of-downloading-them-with-terraform-i?rq=1)

## Tips to upgrade to terraform 0.12

```
terraform 0.12upgrade
```

If you have any codes older than 0.12, please go through official documents first,

- [terraform Input Variables](https://www.terraform.io/docs/configuration/variables.html), a lot of new features you have to know.
- [Upgrading to Terraform v0.12](https://www.terraform.io/upgrade-guides/0-12.html)
- [terraform command 0.12upgrade](https://www.terraform.io/docs/commands/0.12upgrade.html)
- [Announcing Terraform 0.12](https://www.hashicorp.com/blog/announcing-terraform-0-12)

Then here are extra tips for you.

- Upgrade to terraform 0.11 first, if you have any.
- Upgrade terraform moudles to 0.12 first, because terraform 0.12 can't work with 0.11 modules.
- Define `type` for each variable, otherwise you will get weird error messages.

## Tips to upgrade to terraform 0.13+

In fact the command `terraform 0.13upgrade` in terraform v0.13.3 (the latest version currently) doesn't work to convert older versions less than v0.11

So you have to download terraform 0.12 version to do the upgrade. But from hashicorp terraform website, there is only v0.13.x for downloading now.

Here is a simple way if you can run with docker

```
# cd to the terraform tf files folder, run below commands

# do the upgrade within terraform 0.12 container
$ docker run -ti --rm -v $(pwd):/apps -w /apps --entrypoint=sh hashicorp/terraform:0.12.29
/apps # terraform init
/apps # terraform 0.12upgrade -yes
/apps # exit

# double check with 0.13upgrade
$ terraform 0.13upgrade -yes
$
```

# Contributing

- Update [README.md](README.md)
- install [doctoc](https://github.com/thlorenz/doctoc)

```
npm install -g doctoc
```

- update README

```
doctoc --github README.md
```

- commit the update and raise pull request for reviewing.

# Useful terraform modules

1. terraform aws ami helper

usage module to easly find some useful AWS ami id, here is a sample to get latest amazon linux 2 ami id

```terraform
module "helper" {
  source  = "recarnot/ami-helper/aws"
  os      = module.helper.AMAZON_LINUX_2
}

output "id" {
    value = module.helper.ami_id
}

# reference: [recarnot/terraform-aws-ami-helper](https://github.com/recarnot/terraform-aws-ami-helper)
```

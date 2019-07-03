# terraform-best-practices

Terraform Best Practices for AWS users.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  

- [Run terraform command with var-file](#run-terraform-command-with-var-file)
- [Manage s3 backend for tfstate files](#manage-s3-backend-for-tfstate-files)
  - [Notes](#notes)
- [Manage multiple Terraform modules and environments easily with Terragrunt](#manage-multiple-terraform-modules-and-environments-easily-with-terragrunt)
- [Retrieve state meta data from a remote backend](#retrieve-state-meta-data-from-a-remote-backend)
- [Turn on debug when you need do troubleshooting.](#turn-on-debug-when-you-need-do-troubleshooting)
- [Use shared modules](#use-shared-modules)
  - [Notes](#notes-1)
- [Isolate environment](#isolate-environment)
- [Use terraform import to include as many resources you can](#use-terraform-import-to-include-as-many-resources-you-can)
- [Avoid hard coding the resources](#avoid-hard-coding-the-resources)
- [Format terraform code](#format-terraform-code)
- [Enable version control on terraform state files bucket](#enable-version-control-on-terraform-state-files-bucket)
- [Generate README for each module with input and output variables](#generate-readme-for-each-module-with-input-and-output-variables)
- [Update terraform version](#update-terraform-version)
- [Run terraform from docker container](#run-terraform-from-docker-container)
- [Troubleshooting with messy output - (Decommissioned)](#troubleshooting-with-messy-output---decommissioned)
- [Run test](#run-test)
  - [Quick start](#quick-start)
  - [Run test within docker container](#run-test-within-docker-container)
- [Minimum AWS permissions necessary for a Terraform run](#minimum-aws-permissions-necessary-for-a-terraform-run)
- [Tips to deal with lambda functions](#tips-to-deal-with-lambda-functions)
  - [explanation](#explanation)
  - [Notes](#notes-2)
- [usage of variable "self"](#usage-of-variable-self)
  - [One more use case](#one-more-use-case)
- [Use pre-installed Terraform plugins](#use-pre-installed-terraform-plugins)
- [Useful documents you should read](#useful-documents-you-should-read)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Run terraform command with var-file

```
$ cat config/dev.tfvars

name = "dev-stack"
s3_terraform_bucket = "dev-stack-terraform"
tag_team_name = "hello-world"
 
$ terraform plan -var-file=config/dev.tfvars
```

With `var-file`, you can easily manage environment (dev/stag/uat/prod) variables.

With `var-file`, you avoid running terraform with long list of key-value pairs ( `-var foo=bar` )

## Manage s3 backend for tfstate files

Terraform doesn't support [Interpolated variables in terraform backend config](https://github.com/hashicorp/terraform/pull/12067), normally you write a seperate script to define s3 backend bucket name for different environments, but I recommend to hard code it directly as below

Add below code in terraform configuration files.
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
bucket  = "<unique_bucket_name>-terraform-development"
key     = "development/service-1.tfstate"
encrypt = true
region  = "ap-southeast-2"
kms_key_id = "alias/terraform"
dynamodb_table = "terraform-lock"
```

### Notes

- bucket - s3 bucket name, has to be globally unique.
- key - Set some meaningful names for different services and applications, such as vpc.tfstate, application_name.tfstate, etc
- dynamodb_table - optional when you want to enable [State Locking](https://www.terraform.io/docs/state/locking.html)

After you set `config/backend-dev.conf` and `config/dev.tfvars` properly (for each environment). You can easily run terraform as below:

```
env=dev
terraform get -update=true
terraform init -backend-config=config/backend-${env}.conf
terraform plan -var-file=config/${env}.tfvars
terraform apply -var-file=config/${env}.tfvars
```

## Manage multiple Terraform modules and environments easily with Terragrunt

Terragrunt is a thin wrapper for Terraform that provides extra tools for working with multiple Terraform modules. https://www.gruntwork.io

Sample for reference: https://github.com/gruntwork-io/terragrunt-infrastructure-live-example

Its README is too long, if you need a quick start, follow below steps:

```
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

## Retrieve state meta data from a remote backend

Normally we have several layers to manage terraform resources, such as network, database, application layers. After you create the basic network resources, such as vpc, security group, subnets, nat gateway in vpc stack. Your database layer and applications layer should always refer the resource from vpc layer directly via `terraform_remote_state` data srouce. 

```
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config{
    bucket = "${var.s3_terraform_bucket}"
    key = "${var.environment}/vpc.tfstate"
    region="${var.aws_region}"
  }
}
 
# Retrieves the vpc_id and subnet_ids directly from remote backend state files.
resource "aws_xx_xxxx" "main" {
  # ...
  subnet_ids = "${split(",", data.terraform_remote_state.vpc.data_subnets)}"
  vpc_id     = "${data.terraform_remote_state.vpc.vpc_id}"
}
```

## Turn on debug when you need do troubleshooting.

```
TF_LOG=DEBUG terraform <command>

# or if you run with terragrunt
TF_LOG=DEBUG terragrunt <command>
```

## Use shared modules

Manage terraform resource with shared modules, this will save a lot of coding time. No need re-invent the wheel!

You can start from below links: 

[terraform module usage](https://www.terraform.io/docs/modules/usage.html)

[Terraform Module Registry](https://registry.terraform.io/)

[Terraform aws modules](https://github.com/terraform-aws-modules)

### Notes

terraform modules don't support `count` parameter currently. You can follow up this ticket for updates: https://github.com/hashicorp/terraform/issues/953

## Isolate environment

Sometimes, developers like to create a security group and share it to all non-prod (dev/qa) environments. Don't do that, create resources with different name for each environment and each resource.

```
variable "application" {
  description = "application name"
  default = "<replace_with_your_project_or_application_name>"
}

variable "environment" {
  description = "environment name"
}

locals {
  name_prefix    = "${var.application}-${var.environment}"
}

resource "<any_resource>" {
  name = "${local.name_prefix}-<resource_name>"
  ...
}
```
With that, you will easily define the resource with a meaningful and unique name, and you can build more of the same application stack for different developers without change a lot. For example, you update the environment to dev, staging, uat, prod, etc.

>Tips: some aws resource names have length limits, such as less than 24 characters, so when you define variables of application and environment name, use short name.

## Use terraform import to include as many resources you can

Sometimes developers manually created resources. You need to mark these resource and use `terraform import` to include them in codes.

[terraform import](https://www.terraform.io/docs/import/usage.html)

## Avoid hard coding the resources

A sample:
```
account_number=“123456789012"
account_alias="mycompany"
region="us-east-2"
```

The current aws account id, account alias and current region can be input directly via [data sources](https://www.terraform.io/docs/providers/aws/).

```
# The attribute `${data.aws_caller_identity.current.account_id}` will be current account number. 
data "aws_caller_identity" "current" {}

# The attribue `${data.aws_iam_account_alias.current.account_alias}` will be current account alias
data "aws_iam_account_alias" "current" {}

# The attribute `${data.aws_region.current.name}` will be current region
data "aws_region" "current" {}

# Set as [local values](https://www.terraform.io/docs/configuration/locals.html)
locals {
  account_id    = "${data.aws_caller_identity.current.account_id}"
  account_alias = "${data.aws_iam_account_alias.current.account_alias}"
  region        = "${data.aws_region.current.name}"
}
```

## Format terraform code

Always run `terraform fmt` to format terraform configuration files and make them neat.

I used below code in Travis CI pipeline (you can re-use it in any pipelines) to validate and format check the codes before you can merge it to master branch.

      - find . -type f -name "*.tf" -exec dirname {} \;|sort -u | while read m; do (terraform validate -check-variables=false "$m" && echo "√ $m") || exit 1 ; done
      - terraform fmt -check=true -write=false -diff=true
      
## Enable version control on terraform state files bucket

Always set backend to s3 and enable version control on this bucket. 

If you'd like to manage terraform state bucket as well, I recommend using this repostory I wrote [tf_aws_tfstate_bucket](https://github.com/BWITS/tf_aws_tfstate_bucket) to create the bucket and replicate to other regions automatically. 

## Generate README for each module with input and output variables

You needn't manually manage `USAGE` about input variables and outputs. [terraform-docs](https://github.com/segmentio/terraform-docs) can do this job automatically.

```
$ brew install terraform-docs
$ cd terraform/modules/vpc
$ terraform-docs md . > README.md
```

For details on how to run `terraform-docs`, check this repository: https://github.com/segmentio/terraform-docs

There is a simple sample for you to start [tf_aws_acme](https://github.com/BWITS/tf_aws_acme), the README is generatd by `terraform-docs`

## Update terraform version

Hashicorp doesn't have a good qa/build/release process for their software and does not follow semantic versioning rules.

For example, `terraform init` isn't compatible between 0.9 and 0.8. Now they are going to split providers and use "init" to install providers as plugin in coming version 0.10

So recommend to keep updating to latest terraform version

## Run terraform from docker container

Terraform releases official docker containers that you can easily control which version you can run.

Recommend to run terraform docker container, when you set your build job in CI/CD pipeline.

```
TERRAFORM_IMAGE=hashicorp/terraform:0.9.8
TERRAFORM_CMD="docker run -ti --rm -w /app -v ${HOME}/.aws:/root/.aws -v ${HOME}/.ssh:/root/.ssh -v `pwd`:/app -w /app ${TERRAFORM_IMAGE}"
${TERRAFORM_CMD} init
${TERRAFORM_CMD} plan
```

## Troubleshooting with messy output - (Decommissioned)
> (Decommissioned) after terraform v0.12.x, we needn't run with `terraform-landscape` any more. The new terraform output looks nice already.

Sometime, you applied the changes several times, the plan output always prompts there are some changes, essepecially in iam and s3 policy.  It is hard to troubleshooting the problem with messy json output in one line.

With the tool [terraform-landscape](https://github.com/coinbase/terraform-landscape), it improves Terraform plan output to be easier for reading, you can easily find out where is the problem. For details, please go through the project at https://github.com/coinbase/terraform-landscape

    # Install terraform_landscape
    gem install terraform_landscape
    # On MacOS, you can install with brew
    brew install terraform_landscape

    terraform plan -var-file=${env}/${env}.tfvars -input=false -out=plan -lock=false |tee report
    landscape < report

    # run terraform-landscape container as command
    alias landscape="docker run -i --rm -v $(pwd):/apps alpine/landscape:0.1.18"
    landscape --help
    terraform plan |tee report
    landscape - < report
    # Or
    terraform plan | landscape -

Another quick way to handle the messy output is to run below command, if you manually copy the part of messy output to a file

    cat output.txt | grep -Ev '"([^"]*)" => "\1"'

## Run test

Recommend to add [awspec](https://github.com/k1LoW/awspec) tests through [kitchen](https://kitchen.ci/) and [kitchen-terraform](https://newcontext-oss.github.io/kitchen-terraform/).

### Quick start

Reference: repo [terraform-aws-modules/terraform-aws-eks](https://github.com/terraform-aws-modules/terraform-aws-eks#testing)

### Run test within docker container

Reference: [README for terraform awspec container](https://github.com/alpine-docker/bundle-terraform-awspec)

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

Depend on your company or project requirement, you can easily update the resources in `Allow` session which terraform commands should have, and add deny policies in `Deny` session if some of permissions are not required.

## Tips to deal with lambda functions

Headache to save python packages from `pip install` into source codes and generate lambda zip file manually? Here is full codes with solution.

The folder [lambda](./lambda) includes all codes, here is the explanation.

```
$ tree
.
├── lambda.tf              # terraform HCL to deal with lambda
├── pip.sh                 # script to install python packages with pip.
└── source
    ├── .gitignore         # Ignore all other files
    ├── main.py            # Lambda function, replace with yours
    ├── requirements.txt   # python package list, replace with yours.
    └── setup.cfg          # Useful for mac users who installed python using Homebrew
```

Replace `main.py` and `requirements.txt` with your applications.

### explanation

After you run `terraform apply`, it will:

1. install all pip packages into source folder
2. zip the source folder to `source.zip`
3. deploy lambda function with `source.zip`
4. because of `source/.gitignore`, it will ignore all new installed pip packages in git source codes.

This solution is reference from the comments in [Ability to zip AWS Lambda function on the fly](https://github.com/hashicorp/terraform/issues/8344#issuecomment-345807204))

You should be fine to do the same for lambda functions using nodejs (`npm install`) or other languages with this tip.

### Notes

You need have python/pip installed when run terraform commands, if you run in terraform container, make sure you install python/pip in it.

## usage of variable "self"

Quote from terraform documents:
>Attributes of your own resource

>The syntax is self.ATTRIBUTE. For example ${self.private_ip} will interpolate that resource's private IP address.

>Note: The self.ATTRIBUTE syntax is only allowed and valid within provisioners.

### One more use case
```
resource "aws_ecr_repository" "jenkins" {
  name = "${var.image_name}"
  provisioner "local-exec" {
    command = "./deploy-image.sh ${self.repository_url} ${var.jenkins_image_name}"
  }
}

variable "jenkins_image_name" {
  default = "mycompany/jenkins"
  description = "Jenkins image name."
}
```
You can easily define ecr image url (`<account_id>.dkr.ecr.<aws_region>.amazonaws.com/<image_name>`) with ${self.repository_url}

Any attributes in this resource can be self referenced by this way.

Reference: https://github.com/shuaibiyy/terraform-ecs-jenkins/blob/master/docker/main.tf

## Use pre-installed Terraform plugins

There is a way to use pre-installed Terraform plugins instead of downloading them with `terraform init`, the accepted answer below gives the detail:

[Use pre-installed Terraform plugins instead of downloading them with terraform init](https://stackoverflow.com/questions/50944395/use-pre-installed-terraform-plugins-instead-of-downloading-them-with-terraform-i?rq=1)

## Useful documents you should read

[terraform tips & tricks: loops, if-statements, and gotchas](https://blog.gruntwork.io/terraform-tips-tricks-loops-if-statements-and-gotchas-f739bbae55f9)

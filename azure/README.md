
## Manage Blob Storage backend for tfstate files

Terraform doesn't support [Interpolated variables in terraform backend config](https://github.com/hashicorp/terraform/pull/12067), normally you write a seperate script to define a backend storage name for different environments, but I recommend to hard code it.

Add below code in terraform configuration files.
```
$ cat main.tf

terraform {
  required_version = "~> 0.12"

  backend "azurerm" {
    encrypt = true
  }
}
```

Define backend variables for particular environment
```
$ cat config/backend-dev.conf
storage_account_name  = "<unique_storage_account_name>-terraform-development"
container_name = "tfstate"
key     = "development/service-1.tfstate"
encrypt = true
region  = "westus2"
access_key="<access_key>"
```

### Notes
- storage_account_name - Azure Storage account name, has to be globally unique.
- container_name - he name of the blob container.
- key - Set some meaningful names for different services and applications, such as vpc.tfstate, application_name.tfstate, etc
- access_key - Storage Account Access Key


After you set `config/backend-dev.conf` and `config/dev.tfvars` properly (for each environment). You can easily run terraform as below:

```
env=dev
terraform get -update=true
terraform init -backend-config=config/backend-${env}.conf
terraform plan -var-file=config/${env}.tfvars
terraform apply -var-file=config/${env}.tfvars
```

#### Resources
* [Azure RM Backend Documentation](https://www.terraform.io/docs/backends/types/azurerm.html)
* [Tutorial: Store Terraform state in Azure Storage](https://docs.microsoft.com/en-us/azure/terraform/terraform-backend)
* [State Locking](https://www.terraform.io/docs/state/locking.html)
 ## API_Gateway & Cloudwatch

These templates implements a api_gateway, cloudwatch alarm, dashboard and route53 health check, and associated necessary steps required. We used below services :

- API_Gateway
- cloudwatch_dashboard for api
- route53 health check

-- Mention your region, secret and access keys, vpc_id, subnet_ids and ami_id required in the templates.

To run these templates, clone the repository and run terraform apply within its own directory.

For example:

```tf
$ git clone https://github.com/ozbillwang/terraform-best-practices.git
$ cd terraform-best-practices/API_Gateway & CloudWatch
$ terraform apply
```

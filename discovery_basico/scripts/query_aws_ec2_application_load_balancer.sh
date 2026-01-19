#!/bin/sh
# ===========================================================================================================================
# .inspect aws_ec2_application_load_balancer;
# +--------------------------+--------------------------+----------------------------------------------------------+
# | column                   | type                     | description                                              |
# +--------------------------+--------------------------+----------------------------------------------------------+
# | _ctx                     | jsonb                    | Steampipe context in JSON form.                          |
# | account_id               | text                     | The AWS Account ID in which the resource is located.     |
# | akas                     | jsonb                    | Array of globally unique identifier strings (also known  |
# |                          |                          | as) for the resource.                                    |
# | arn                      | text                     | The Amazon Resource Name (ARN) of the load balancer.     |
# | availability_zones       | jsonb                    | The subnets for the load balancer.                       |
# | canonical_hosted_zone_id | text                     | The ID of the Amazon Route 53 hosted zone associated wit |
# |                          |                          | h the load balancer.                                     |
# | created_time             | timestamp with time zone | The date and time the load balancer was created.         |
# | customer_owned_ipv4_pool | text                     | The ID of the customer-owned address pool.               |
# | dns_name                 | text                     | The public DNS name of the load balancer.                |
# | ip_address_type          | text                     | The type of IP addresses used by the subnets for your lo |
# |                          |                          | ad balancer.                                             |
# | load_balancer_attributes | jsonb                    | The AWS account ID of the image owner.                   |
# | name                     | text                     | The friendly name of the Load Balancer that was provided |
# |                          |                          |  during resource creation.                               |
# | partition                | text                     | The AWS partition in which the resource is located (aws, |
# |                          |                          |  aws-cn, or aws-us-gov).                                 |
# | region                   | text                     | The AWS Region in which the resource is located.         |
# | scheme                   | text                     | The load balancing scheme of load balancer.              |
# | security_groups          | jsonb                    | The IDs of the security groups for the load balancer.    |
# | sp_connection_name       | text                     | Steampipe connection name.                               |
# | sp_ctx                   | jsonb                    | Steampipe context in JSON form.                          |
# | state_code               | text                     | Current state of the load balancer.                      |
# | state_reason             | text                     | A description of the state.                              |
# | tags                     | jsonb                    | A map of tags for the resource.                          |
# | tags_src                 | jsonb                    | A list of tags attached to the load balancer.            |
# | title                    | text                     | Title of the resource.                                   |
# | type                     | text                     | The type of load balancer.                               |
# | vpc_id                   | text                     | The ID of the VPC for the load balancer.                 |
# +--------------------------+--------------------------+----------------------------------------------------------+

steampipe query "
select
  region,
  arn,
  title,
  scheme,
  type,
  account_id,
  sp_connection_name as profile_discovery
from
  ${TABLE_PREFIX}.aws_ec2_application_load_balancer;
" --output csv 1>${CSV_DIR}/aws_ec2_application_load_balancer.csv 2>&1

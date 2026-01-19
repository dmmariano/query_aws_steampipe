#!/bin/sh
# ===========================================================================================================================
# .inspect aws_ec2_network_load_balancer;
# +--------------------------------------------------------------+--------------------------+----------------------+
# | column                                                       | type                     | description          |
# +--------------------------------------------------------------+--------------------------+----------------------+
# | _ctx                                                         | jsonb                    | Steampipe context in |
# |                                                              |                          |  JSON form.          |
# | account_id                                                   | text                     | The AWS Account ID i |
# |                                                              |                          | n which the resource |
# |                                                              |                          |  is located.         |
# | akas                                                         | jsonb                    | Array of globally un |
# |                                                              |                          | ique identifier stri |
# |                                                              |                          | ngs (also known as)  |
# |                                                              |                          | for the resource.    |
# | arn                                                          | text                     | The Amazon Resource  |
# |                                                              |                          | Name (ARN) of the lo |
# |                                                              |                          | ad balancer          |
# | availability_zones                                           | jsonb                    | The subnets for the  |
# |                                                              |                          | load balancer        |
# | canonical_hosted_zone_id                                     | text                     | The ID of the Amazon |
# |                                                              |                          |  Route 53 hosted zon |
# |                                                              |                          | e associated with th |
# |                                                              |                          | e load balancer      |
# | created_time                                                 | timestamp with time zone | The date and time th |
# |                                                              |                          | e load balancer was  |
# |                                                              |                          | created              |
# | customer_owned_ipv4_pool                                     | text                     | The ID of the custom |
# |                                                              |                          | er-owned address poo |
# |                                                              |                          | l                    |
# | dns_name                                                     | text                     | The public DNS name  |
# |                                                              |                          | of the load balancer |
# | enforce_security_group_inbound_rules_on_private_link_traffic | text                     | Indicates whether to |
# |                                                              |                          |  evaluate inbound se |
# |                                                              |                          | curity group rules f |
# |                                                              |                          | or traffic sent to a |
# |                                                              |                          |  Network Load Balanc |
# |                                                              |                          | er through Amazon We |
# |                                                              |                          | b Services PrivateLi |
# |                                                              |                          | nk.                  |
# | ip_address_type                                              | text                     | The type of IP addre |
# |                                                              |                          | sses used by the sub |
# |                                                              |                          | nets for your load b |
# |                                                              |                          | alancer              |
# | load_balancer_attributes                                     | jsonb                    | The AWS account ID o |
# |                                                              |                          | f the image owner    |
# | name                                                         | text                     | The friendly name of |
# |                                                              |                          |  the Load Balancer   |
# | partition                                                    | text                     | The AWS partition in |
# |                                                              |                          |  which the resource  |
# |                                                              |                          | is located (aws, aws |
# |                                                              |                          | -cn, or aws-us-gov). |
# | region                                                       | text                     | The AWS Region in wh |
# |                                                              |                          | ich the resource is  |
# |                                                              |                          | located.             |
# | scheme                                                       | text                     | The load balancing s |
# |                                                              |                          | cheme of load balanc |
# |                                                              |                          | er                   |
# | security_groups                                              | jsonb                    | The IDs of the secur |
# |                                                              |                          | ity groups for the l |
# |                                                              |                          | oad balancer         |
# | sp_connection_name                                           | text                     | Steampipe connection |
# |                                                              |                          |  name.               |
# | sp_ctx                                                       | jsonb                    | Steampipe context in |
# |                                                              |                          |  JSON form.          |
# | state_code                                                   | text                     | Current state of the |
# |                                                              |                          |  load balancer       |
# | state_reason                                                 | text                     | A description of the |
# |                                                              |                          |  state               |
# | tags                                                         | jsonb                    | A map of tags for th |
# |                                                              |                          | e resource.          |
# | tags_src                                                     | jsonb                    | A list of tags attac |
# |                                                              |                          | hed to the load bala |
# |                                                              |                          | ncer                 |
# | title                                                        | text                     | Title of the resourc |
# |                                                              |                          | e.                   |
# | type                                                         | text                     | The type of load bal |
# |                                                              |                          | ancer                |
# | vpc_id                                                       | text                     | The ID of the VPC fo |
# |                                                              |                          | r the load balancer  |
# +--------------------------------------------------------------+--------------------------+----------------------+

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
  ${TABLE_PREFIX}.aws_ec2_network_load_balancer;
" --output csv 1>${CSV_DIR}/aws_ec2_network_load_balancer.csv 2>&1

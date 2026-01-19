#!/bin/sh
# ===========================================================================================================================
# .inspect aws_ec2_classic_load_balancer;
# +-----------------------------------+--------------------------+-------------------------------------------------+
# | column                            | type                     | description                                     |
# +-----------------------------------+--------------------------+-------------------------------------------------+
# | _ctx                              | jsonb                    | Steampipe context in JSON form.                 |
# | access_log_emit_interval          | bigint                   | The interval for publishing the access logs.    |
# | access_log_enabled                | boolean                  | Specifies whether access logs are enabled for t |
# |                                   |                          | he load balancer.                               |
# | access_log_s3_bucket_name         | text                     | The name of the Amazon S3 bucket where the acce |
# |                                   |                          | ss logs are stored.                             |
# | access_log_s3_bucket_prefix       | text                     | The logical hierarchy you created for your Amaz |
# |                                   |                          | on S3 bucket.                                   |
# | account_id                        | text                     | The AWS Account ID in which the resource is loc |
# |                                   |                          | ated.                                           |
# | additional_attributes             | jsonb                    | A list of additional attributes.                |
# | akas                              | jsonb                    | Array of globally unique identifier strings (al |
# |                                   |                          | so known as) for the resource.                  |
# | app_cookie_stickiness_policies    | jsonb                    | A list of the stickiness policies created using |
# |                                   |                          |  CreateAppCookieStickinessPolicy.               |
# | arn                               | text                     | The Amazon Resource Name (ARN) specifying the c |
# |                                   |                          | lassic load balancer.                           |
# | availability_zones                | jsonb                    | A list of the Availability Zones for the load b |
# |                                   |                          | alancer.                                        |
# | backend_server_descriptions       | jsonb                    | A list of information about your EC2 instances. |
# | canonical_hosted_zone_name        | text                     | The name of the Amazon Route 53 hosted zone for |
# |                                   |                          |  the load balancer.                             |
# | canonical_hosted_zone_name_id     | text                     | The ID of the Amazon Route 53 hosted zone for t |
# |                                   |                          | he load balancer.                               |
# | connection_draining_enabled       | boolean                  | Specifies whether connection draining is enable |
# |                                   |                          | d for the load balancer.                        |
# | connection_draining_timeout       | bigint                   | The maximum time, in seconds, to keep the exist |
# |                                   |                          | ing connections open before deregistering the i |
# |                                   |                          | nstances.                                       |
# | connection_settings_idle_timeout  | bigint                   | The time, in seconds, that the connection is al |
# |                                   |                          | lowed to be idle (no data has been sent over th |
# |                                   |                          | e connection) before it is closed by the load b |
# |                                   |                          | alancer.                                        |
# | created_time                      | timestamp with time zone | The date and time the load balancer was created |
# |                                   |                          | .                                               |
# | cross_zone_load_balancing_enabled | boolean                  | Specifies whether cross-zone load balancing is  |
# |                                   |                          | enabled for the load balancer.                  |
# | dns_name                          | text                     | The DNS name of the load balancer.              |
# | health_check_interval             | bigint                   | The approximate interval, in seconds, between h |
# |                                   |                          | ealth checks of an individual instance.         |
# | health_check_target               | text                     | The instance being checked. The protocol is eit |
# |                                   |                          | her TCP, HTTP, HTTPS, or SSL. The range of vali |
# |                                   |                          | d ports is one (1) through 65535.               |
# | health_check_timeout              | bigint                   | The amount of time, in seconds, during which no |
# |                                   |                          |  response means a failed health check.          |
# | healthy_threshold                 | bigint                   | The number of consecutive health checks success |
# |                                   |                          | es required before moving the instance to the H |
# |                                   |                          | ealthy state.                                   |
# | instances                         | jsonb                    | A list of the IDs of the instances for the load |
# |                                   |                          |  balancer.                                      |
# | lb_cookie_stickiness_policies     | jsonb                    | A list of the stickiness policies created using |
# |                                   |                          |  CreateLBCookieStickinessPolicy.                |
# | listener_descriptions             | jsonb                    | A list of the listeners for the load balancer   |
# | name                              | text                     | The friendly name of the Load Balancer.         |
# | other_policies                    | jsonb                    | A list of policies other than the stickiness po |
# |                                   |                          | licies.                                         |
# | partition                         | text                     | The AWS partition in which the resource is loca |
# |                                   |                          | ted (aws, aws-cn, or aws-us-gov).               |
# | region                            | text                     | The AWS Region in which the resource is located |
# |                                   |                          | .                                               |
# | scheme                            | text                     | The load balancing scheme of load balancer.     |
# | security_groups                   | jsonb                    | A list of the security groups for the load bala |
# |                                   |                          | ncer.                                           |
# | source_security_group_name        | text                     | The name of the security group.                 |
# | source_security_group_owner_alias | text                     | The owner of the security group.                |
# | sp_connection_name                | text                     | Steampipe connection name.                      |
# | sp_ctx                            | jsonb                    | Steampipe context in JSON form.                 |
# | subnets                           | jsonb                    | A list of the IDs of the subnets for the load b |
# |                                   |                          | alancer.                                        |
# | tags                              | jsonb                    | A map of tags for the resource.                 |
# | tags_src                          | jsonb                    | A list of tags attached to the load balancer.   |
# | title                             | text                     | Title of the resource.                          |
# | unhealthy_threshold               | bigint                   | The number of consecutive health check failures |
# |                                   |                          |  required before moving the instance to the Unh |
# |                                   |                          | ealthy state.                                   |
# | vpc_id                            | text                     | The ID of the VPC for the load balancer.        |
# +-----------------------------------+--------------------------+-------------------------------------------------+

steampipe query "
select
  region,
  arn,
  title,
  scheme,
  'classic' as type,
  account_id,
  sp_connection_name as profile_discovery
from
  ${TABLE_PREFIX}.aws_ec2_classic_load_balancer;
" --output csv 1>${CSV_DIR}/aws_ec2_classic_load_balancer.csv 2>&1

#!/bin/sh
# ===========================================================================================================================
# .inspect aws_elasticache_cluster;
# +----------------------------------------+--------------------------+------------------------------------------+
# | column                                 | type                     | description                              |
# +----------------------------------------+--------------------------+------------------------------------------+
# | _ctx                                   | jsonb                    | Steampipe context in JSON form.          |
# | account_id                             | text                     | The AWS Account ID in which the resource |
# |                                        |                          |  is located.                             |
# | akas                                   | jsonb                    | Array of globally unique identifier stri |
# |                                        |                          | ngs (also known as) for the resource.    |
# | arn                                    | text                     | The ARN (Amazon Resource Name) of the ca |
# |                                        |                          | che cluster.                             |
# | at_rest_encryption_enabled             | boolean                  | A flag that enables encryption at-rest w |
# |                                        |                          | hen set to true.                         |
# | auth_token_enabled                     | boolean                  | A flag that enables using an AuthToken ( |
# |                                        |                          | password) when issuing Redis commands.   |
# | auth_token_last_modified_date          | timestamp with time zone | The date the auth token was last modifie |
# |                                        |                          | d.                                       |
# | auto_minor_version_upgrade             | boolean                  | This parameter is currently disabled.    |
# | cache_cluster_create_time              | timestamp with time zone | The date and time when the cluster was c |
# |                                        |                          | reated.                                  |
# | cache_cluster_id                       | text                     | An unique identifier for ElastiCache clu |
# |                                        |                          | ster.                                    |
# | cache_cluster_status                   | text                     | The current state of this cluster, one o |
# |                                        |                          | f the following values: available, creat |
# |                                        |                          | ing, deleted, deleting, incompatible-net |
# |                                        |                          | work, modifying, rebooting cluster nodes |
# |                                        |                          | , restore-failed, or snapshotting.       |
# | cache_node_type                        | text                     | The name of the compute and memory capac |
# |                                        |                          | ity node type for the cluster.           |
# | cache_nodes                            | jsonb                    | A list of cache nodes that are members o |
# |                                        |                          | f the cluster.                           |
# | cache_parameter_group                  | jsonb                    | Status of the cache parameter group.     |
# | cache_security_groups                  | jsonb                    | A list of cache security group elements, |
# |                                        |                          |  composed of name and status sub-element |
# |                                        |                          | s.                                       |
# | cache_subnet_group_name                | text                     | The name of the cache subnet group assoc |
# |                                        |                          | iated with the cluster.                  |
# | client_download_landing_page           | text                     | The URL of the web page where you can do |
# |                                        |                          | wnload the latest ElastiCache client lib |
# |                                        |                          | rary.                                    |
# | configuration_endpoint                 | jsonb                    | Represents a Memcached cluster endpoint  |
# |                                        |                          | which can be used by an application to c |
# |                                        |                          | onnect to any node in the cluster.       |
# | engine                                 | text                     | The name of the cache engine (memcached  |
# |                                        |                          | or redis) to be used for this cluster.   |
# | engine_version                         | text                     | The version of the cache engine that is  |
# |                                        |                          | used in this cluster.                    |
# | ip_discovery                           | text                     | The network type associated with the clu |
# |                                        |                          | ster, either ipv4 | ipv6.                |
# | log_delivery_configurations            | jsonb                    | Returns the destination, format, and typ |
# |                                        |                          | e of the logs.                           |
# | network_type                           | text                     | Must be either ipv4 | ipv6 | dual_stack. |
# | notification_configuration             | jsonb                    | Describes a notification topic and its s |
# |                                        |                          | tatus.                                   |
# | num_cache_nodes                        | bigint                   | The number of cache nodes in the cluster |
# |                                        |                          | .                                        |
# | partition                              | text                     | The AWS partition in which the resource  |
# |                                        |                          | is located (aws, aws-cn, or aws-us-gov). |
# | pending_modified_values                | jsonb                    | A group of settings that are applied to  |
# |                                        |                          | the cluster in the future, or that are c |
# |                                        |                          | urrently being applied.                  |
# | preferred_availability_zone            | text                     | The name of the Availability Zone in whi |
# |                                        |                          | ch the cluster is located or 'Multiple'  |
# |                                        |                          | if the cache nodes are located in differ |
# |                                        |                          | ent Availability Zones.                  |
# | preferred_maintenance_window           | text                     | Specifies the weekly time range during w |
# |                                        |                          | hich maintenance on the cluster is perfo |
# |                                        |                          | rmed.                                    |
# | preferred_outpost_arn                  | text                     | The outpost ARN in which the cache clust |
# |                                        |                          | er is created.                           |
# | region                                 | text                     | The AWS Region in which the resource is  |
# |                                        |                          | located.                                 |
# | replication_group_id                   | text                     | The replication group to which this clus |
# |                                        |                          | ter belongs.                             |
# | replication_group_log_delivery_enabled | boolean                  | A boolean value indicating whether log d |
# |                                        |                          | elivery is enabled for the replication g |
# |                                        |                          | roup.                                    |
# | security_groups                        | jsonb                    | A list of VPC Security Groups associated |
# |                                        |                          |  with the cluster.                       |
# | snapshot_retention_limit               | bigint                   | The number of days for which ElastiCache |
# |                                        |                          |  retains automatic cluster snapshots bef |
# |                                        |                          | ore deleting them.                       |
# | snapshot_window                        | text                     | The daily time range (in UTC) during whi |
# |                                        |                          | ch ElastiCache begins taking a daily sna |
# |                                        |                          | pshot of your cluster.                   |
# | sp_connection_name                     | text                     | Steampipe connection name.               |
# | sp_ctx                                 | jsonb                    | Steampipe context in JSON form.          |
# | tags                                   | jsonb                    | A map of tags for the resource.          |
# | tags_src                               | jsonb                    | A list of tags associated with the clust |
# |                                        |                          | er.                                      |
# | title                                  | text                     | Title of the resource.                   |
# | transit_encryption_enabled             | boolean                  | A flag that enables in-transit encryptio |
# |                                        |                          | n when set to true.                      |
# | transit_encryption_mode                | text                     | A setting that allows you to migrate you |
# |                                        |                          | r clients to use in-transit encryption,  |
# |                                        |                          | with no downtime.                        |
# +----------------------------------------+--------------------------+------------------------------------------+

steampipe query "
select
  region,
  preferred_availability_zone,
  title,
  num_cache_nodes,
  cache_node_type,
  engine,
  engine_version,
  account_id,
  sp_connection_name as profile_discovery
from
  ${TABLE_PREFIX}.aws_elasticache_cluster;
" --output csv 1>${CSV_DIR}/aws_elasticache_cluster.csv 2>&1


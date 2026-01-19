#!/bin/sh
# ===========================================================================================================================
# .inspect aws_rds_db_cluster;
# +---------------------------------------------+--------------------------+----------------------------------------------------+
# | column                                      | type                     | description                                        |
# +---------------------------------------------+--------------------------+----------------------------------------------------+
# | _ctx                                        | jsonb                    | Steampipe context in JSON form.                    |
# | account_id                                  | text                     | The AWS Account ID in which the resource is locate |
# |                                             |                          | d.                                                 |
# | activity_stream_kinesis_stream_name         | text                     | The name of the Amazon Kinesis data stream used fo |
# |                                             |                          | r the database activity stream.                    |
# | activity_stream_kms_key_id                  | text                     | The AWS KMS key identifier used for encrypting mes |
# |                                             |                          | sages in the database activity stream.             |
# | activity_stream_mode                        | text                     | The mode of the database activity stream.          |
# | activity_stream_status                      | text                     | The status of the database activity stream.        |
# | akas                                        | jsonb                    | Array of globally unique identifier strings (also  |
# |                                             |                          | known as) for the resource.                        |
# | allocated_storage                           | bigint                   | Specifies the allocated storage size in gibibytes  |
# |                                             |                          | (GiB).                                             |
# | arn                                         | text                     | The Amazon Resource Name (ARN) for the DB Cluster. |
# | associated_roles                            | jsonb                    | A list of AWS IAM roles that are associated with t |
# |                                             |                          | he DB cluster.                                     |
# | auto_minor_version_upgrade                  | boolean                  | A value that indicates that minor version patches  |
# |                                             |                          | are applied automatically. This setting is only fo |
# |                                             |                          | r non-Aurora Multi-AZ DB clusters.                 |
# | automatic_restart_time                      | timestamp with time zone | The time when a stopped DB cluster is restarted au |
# |                                             |                          | tomatically.                                       |
# | availability_zones                          | jsonb                    | A list of Availability Zones (AZs) where instances |
# |                                             |                          |  in the DB cluster can be created.                 |
# | aws_backup_recovery_point_arn               | text                     | The Amazon Resource Name (ARN) of the recovery poi |
# |                                             |                          | nt in Amazon Web Services Backup.                  |
# | backtrack_consumed_change_records           | bigint                   | The number of change records stored for Backtrack. |
# | backtrack_window                            | bigint                   | The target backtrack window, in seconds.           |
# | backup_retention_period                     | bigint                   | Specifies the number of days for which automatic D |
# |                                             |                          | B snapshots are retained.                          |
# | capacity                                    | bigint                   | The current capacity of an Aurora Serverless DB cl |
# |                                             |                          | uster.                                             |
# | certificate_details                         | jsonb                    | The details of the DB instance’s server certificat |
# |                                             |                          | e.                                                 |
# | character_set_name                          | text                     | Specifies the name of the character set that this  |
# |                                             |                          | cluster is associated with.                        |
# | clone_group_id                              | text                     | Identifies the clone group to which the DB cluster |
# |                                             |                          |  is associated.                                    |
# | copy_tags_to_snapshot                       | boolean                  | Specifies whether tags are copied from the DB clus |
# |                                             |                          | ter to snapshots of the DB cluster, or not.        |
# | create_time                                 | timestamp with time zone | Specifies the time when the DB cluster was created |
# |                                             |                          | .                                                  |
# | cross_account_clone                         | boolean                  | Specifies whether the DB cluster is a clone of a D |
# |                                             |                          | B cluster owned by a different AWS account, or not |
# |                                             |                          | .                                                  |
# | custom_endpoints                            | jsonb                    | A list of all custom endpoints associated with the |
# |                                             |                          |  cluster.                                          |
# | database_name                               | text                     | Contains the name of the initial database of this  |
# |                                             |                          | DB cluster that was provided at create time.       |
# | db_cluster_identifier                       | text                     | The friendly name to identify the DB Cluster.      |
# | db_cluster_instance_class                   | text                     | The name of the compute and memory capacity class  |
# |                                             |                          | of the DB instance.                                |
# | db_cluster_parameter_group                  | text                     | Specifies the name of the DB cluster parameter gro |
# |                                             |                          | up for the DB cluster.                             |
# | db_subnet_group                             | text                     | Specifies information on the subnet group associat |
# |                                             |                          | ed with the DB cluster.                            |
# | deletion_protection                         | boolean                  | Specifies whether the DB cluster has deletion prot |
# |                                             |                          | ection enabled, or not.                            |
# | domain_memberships                          | jsonb                    | A list of Active Directory Domain membership recor |
# |                                             |                          | ds associated with the DB cluster.                 |
# | earliest_backtrack_time                     | timestamp with time zone | The earliest time to which a DB cluster can be bac |
# |                                             |                          | ktracked.                                          |
# | earliest_restorable_time                    | timestamp with time zone | The earliest time to which a database can be resto |
# |                                             |                          | red with point-in-time restore.                    |
# | enabled_cloudwatch_logs_exports             | jsonb                    | A list of log types that this DB cluster is config |
# |                                             |                          | ured to export to CloudWatch Logs.                 |
# | endpoint                                    | text                     | Specifies the connection endpoint for the primary  |
# |                                             |                          | instance of the DB cluster.                        |
# | engine                                      | text                     | The name of the database engine to be used for thi |
# |                                             |                          | s DB cluster.                                      |
# | engine_mode                                 | text                     | The DB engine mode of the DB cluster.              |
# | engine_version                              | text                     | Indicates the database engine version.             |
# | global_write_forwarding_requested           | boolean                  | Specifies whether you have requested to enable wri |
# |                                             |                          | te forwarding for a secondary cluster in an Aurora |
# |                                             |                          |  global database, or not.                          |
# | global_write_forwarding_status              | text                     | Specifies whether a secondary cluster in an Aurora |
# |                                             |                          |  global database has write forwarding enabled, or  |
# |                                             |                          | not.                                               |
# | hosted_zone_id                              | text                     | Specifies the ID that Amazon Route 53 assigns when |
# |                                             |                          |  you create a hosted zone.                         |
# | http_endpoint_enabled                       | boolean                  | Specifies whether the HTTP endpoint for an Aurora  |
# |                                             |                          | Serverless DB cluster is enabled, or not.          |
# | iam_database_authentication_enabled         | boolean                  | Specifies whether the the mapping of AWS IAM accou |
# |                                             |                          | nts to database accounts is enabled, or not.       |
# | io_optimized_next_allowed_modification_time | timestamp with time zone | The next time you can modify the DB cluster to use |
# |                                             |                          |  the aurora-iopt1 storage type. This setting is on |
# |                                             |                          | ly for Aurora DB clusters.                         |
# | kms_key_id                                  | text                     | The AWS KMS key identifier for the encrypted DB cl |
# |                                             |                          | uster.                                             |
# | latest_restorable_time                      | timestamp with time zone | Specifies the latest time to which a database can  |
# |                                             |                          | be restored with point-in-time restore.            |
# | limitless_database                          | jsonb                    | The details for Aurora Limitless Database.         |
# | local_write_forwarding_status               | text                     | Indicates whether an Aurora DB cluster has in-clus |
# |                                             |                          | ter write forwarding enabled, not enabled, request |
# |                                             |                          | ed, or is in the process of enabling it.           |
# | master_user_name                            | text                     | Contains the master username for the DB cluster.   |
# | master_user_secret                          | jsonb                    | The secret managed by RDS in Amazon Web Services S |
# |                                             |                          | ecrets Manager for the master user password.       |
# | members                                     | jsonb                    | A list of instances that make up the DB cluster.   |
# | monitoring_interval                         | bigint                   | The interval, in seconds, between points when Enha |
# |                                             |                          | nced Monitoring metrics are collected for the DB c |
# |                                             |                          | luster.                                            |
# | monitoring_role_arn                         | text                     | The ARN for the IAM role that permits RDS to send  |
# |                                             |                          | Enhanced Monitoring metrics to Amazon CloudWatch L |
# |                                             |                          | ogs.                                               |
# | multi_az                                    | boolean                  | Specifies whether the DB cluster has instances in  |
# |                                             |                          | multiple Availability Zones, or not.               |
# | network_type                                | text                     | The network type of the DB instance.               |
# | option_group_memberships                    | jsonb                    | A list of option group memberships for this DB clu |
# |                                             |                          | ster.                                              |
# | partition                                   | text                     | The AWS partition in which the resource is located |
# |                                             |                          |  (aws, aws-cn, or aws-us-gov).                     |
# | pending_maintenance_actions                 | jsonb                    | A list that provides details about the pending mai |
# |                                             |                          | ntenance actions for the resource.                 |
# | pending_modified_values                     | jsonb                    | Information about pending changes to the DB cluste |
# |                                             |                          | r.                                                 |
# | percent_progress                            | text                     | Specifies the progress of the operation as a perce |
# |                                             |                          | ntage.                                             |
# | performance_insights_enabled                | boolean                  | Indicates whether Performance Insights is enabled  |
# |                                             |                          | for the DB cluster.                                |
# | performance_insights_kms_key_id             | text                     | The Amazon Web Services KMS key identifier for enc |
# |                                             |                          | ryption of Performance Insights data.              |
# | performance_insights_retention_period       | bigint                   | The number of days to retain Performance Insights  |
# |                                             |                          | data.                                              |
# | port                                        | bigint                   | Specifies the port that the database engine is lis |
# |                                             |                          | tening on.                                         |
# | preferred_backup_window                     | text                     | Specifies the daily time range during which automa |
# |                                             |                          | ted backups are created.                           |
# | preferred_maintenance_window                | text                     | Specifies the weekly time range during which syste |
# |                                             |                          | m maintenance can occur                            |
# | publicly_accessible                         | boolean                  | Indicates whether the DB cluster is publicly acces |
# |                                             |                          | sible.                                             |
# | read_replica_identifiers                    | jsonb                    | A list of identifiers of the read replicas associa |
# |                                             |                          | ted with this DB cluster.                          |
# | reader_endpoint                             | text                     | The reader endpoint for the DB cluster.            |
# | region                                      | text                     | The AWS Region in which the resource is located.   |
# | resource_id                                 | text                     | The AWS Region-unique, immutable identifier for th |
# |                                             |                          | e DB cluster.                                      |
# | scaling_configuration_info                  | jsonb                    | The scaling configuration for an Aurora DB cluster |
# |                                             |                          |  in serverless DB engine mode.                     |
# | serverless_v2_scaling_configuration         | jsonb                    | The scaling configuration for an Aurora Serverless |
# |                                             |                          |  v2 DB cluster.                                    |
# | sp_connection_name                          | text                     | Steampipe connection name.                         |
# | sp_ctx                                      | jsonb                    | Steampipe context in JSON form.                    |
# | status                                      | text                     | Specifies the status of this DB Cluster.           |
# | storage_encrypted                           | boolean                  | Specifies whether the DB cluster is encrypted, or  |
# |                                             |                          | not.                                               |
# | storage_throughput                          | bigint                   | The storage throughput for the DB cluster.         |
# | storage_type                                | text                     | The storage type associated with the DB cluster.   |
# | tags                                        | jsonb                    | A map of tags for the resource.                    |
# | tags_src                                    | jsonb                    | A list of tags attached to the DB Cluster.         |
# | title                                       | text                     | Title of the resource.                             |
# | vpc_security_groups                         | jsonb                    | A list of VPC security groups that the DB cluster  |
# |                                             |                          | belongs to.                                        |
# +---------------------------------------------+--------------------------+----------------------------------------------------+

steampipe query "
select
  region,
  title,
  status,
  engine,
  jsonb_array_length( members ) as nodes,
  account_id,
  sp_connection_name as profile_discovery
from
  ${TABLE_PREFIX}.aws_rds_db_cluster;
" --output csv 1>${CSV_DIR}/aws_rds_db_cluster.csv 2>&1


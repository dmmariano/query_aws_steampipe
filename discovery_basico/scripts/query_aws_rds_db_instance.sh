#!/bin/sh
# ===========================================================================================================================
# .inspect aws_rds_db_instance;
# +--------------------------------------------+--------------------------+-----------------------------------------------------+
# | column                                     | type                     | description                                         |
# +--------------------------------------------+--------------------------+-----------------------------------------------------+
# | _ctx                                       | jsonb                    | Steampipe context in JSON form.                     |
# | account_id                                 | text                     | The AWS Account ID in which the resource is located |
# |                                            |                          | .                                                   |
# | akas                                       | jsonb                    | Array of globally unique identifier strings (also k |
# |                                            |                          | nown as) for the resource.                          |
# | allocated_storage                          | bigint                   | Specifies the allocated storage size specified in g |
# |                                            |                          | ibibytes(GiB).                                      |
# | arn                                        | text                     | The Amazon Resource Name (ARN) for the DB Instance. |
# | associated_roles                           | jsonb                    | A list of AWS IAM roles that are associated with th |
# |                                            |                          | e DB instance.                                      |
# | auto_minor_version_upgrade                 | boolean                  | Specifies whether minor version patches are applied |
# |                                            |                          |  automatically, or not.                             |
# | availability_zone                          | text                     | Specifies the name of the Availability Zone the DB  |
# |                                            |                          | instance is located in.                             |
# | backup_retention_period                    | bigint                   | Specifies the number of days for which automatic DB |
# |                                            |                          |  snapshots are retained.                            |
# | ca_certificate_identifier                  | text                     | The identifier of the CA certificate for this DB in |
# |                                            |                          | stance.                                             |
# | certificate                                | jsonb                    | The CA certificate associated with the DB instance. |
# | character_set_name                         | text                     | Specifies the name of the character set that this i |
# |                                            |                          | nstance is associated with.                         |
# | class                                      | text                     | Contains the name of the compute and memory capacit |
# |                                            |                          | y class of the DB instance.                         |
# | copy_tags_to_snapshot                      | boolean                  | Specifies whether tags are copied from the DB insta |
# |                                            |                          | nce to snapshots of the DB instance, or not.        |
# | create_time                                | timestamp with time zone | Provides the date and time the DB instance was crea |
# |                                            |                          | ted.                                                |
# | customer_owned_ip_enabled                  | boolean                  | Specifies whether a customer-owned IP address (CoIP |
# |                                            |                          | ) is enabled for an RDS on Outposts DB instance, or |
# |                                            |                          |  not.                                               |
# | db_cluster_identifier                      | text                     | The friendly name to identify the DB cluster, that  |
# |                                            |                          | the DB instance is a member of.                     |
# | db_instance_identifier                     | text                     | The friendly name to identify the DB Instance.      |
# | db_name                                    | text                     | Contains the name of the initial database of this i |
# |                                            |                          | nstance that was provided at create time.           |
# | db_parameter_groups                        | jsonb                    | A list of DB parameter groups applied to this DB in |
# |                                            |                          | stance.                                             |
# | db_security_groups                         | jsonb                    | A list of DB security group associated with the DB  |
# |                                            |                          | instance.                                           |
# | db_subnet_group_arn                        | text                     | The Amazon Resource Name (ARN) for the DB subnet gr |
# |                                            |                          | oup.                                                |
# | db_subnet_group_description                | text                     | Provides the description of the DB subnet group.    |
# | db_subnet_group_name                       | text                     | The name of the DB subnet group.                    |
# | db_subnet_group_status                     | text                     | Provides the status of the DB subnet group.         |
# | deletion_protection                        | boolean                  | Specifies whether the DB instance has deletion prot |
# |                                            |                          | ection enabled, or not.                             |
# | domain_memberships                         | jsonb                    | A list of Active Directory Domain membership record |
# |                                            |                          | s associated with the DB instance.                  |
# | enabled_cloudwatch_logs_exports            | jsonb                    | A list of log types that this DB instance is config |
# |                                            |                          | ured to export to CloudWatch Logs.                  |
# | endpoint_address                           | text                     | Specifies the DNS address of the DB instance.       |
# | endpoint_hosted_zone_id                    | text                     | Specifies the ID that Amazon Route 53 assigns when  |
# |                                            |                          | you create a hosted zone.                           |
# | endpoint_port                              | bigint                   | Specifies the port that the database engine is list |
# |                                            |                          | ening on.                                           |
# | engine                                     | text                     | The name of the database engine to be used for this |
# |                                            |                          |  DB instance.                                       |
# | engine_version                             | text                     | Indicates the database engine version.              |
# | enhanced_monitoring_resource_arn           | text                     | The ARN of the Amazon CloudWatch Logs log stream th |
# |                                            |                          | at receives the Enhanced Monitoring metrics data fo |
# |                                            |                          | r the DB instance.                                  |
# | iam_database_authentication_enabled        | boolean                  | Specifies whether the the mapping of AWS IAM accoun |
# |                                            |                          | ts to database accounts is enabled, or not.         |
# | iops                                       | bigint                   | Specifies the Provisioned IOPS (I/O operations per  |
# |                                            |                          | second) value.                                      |
# | kms_key_id                                 | text                     | The AWS KMS key identifier for the encrypted DB ins |
# |                                            |                          | tance.                                              |
# | latest_restorable_time                     | timestamp with time zone | Specifies the latest time to which a database can b |
# |                                            |                          | e restored with point-in-time restore.              |
# | license_model                              | text                     | License model information for this DB instance.     |
# | master_user_name                           | text                     | Contains the master username for the DB instance.   |
# | max_allocated_storage                      | bigint                   | The upper limit to which Amazon RDS can automatical |
# |                                            |                          | ly scale the storage of the DB instance.            |
# | monitoring_interval                        | bigint                   | The interval, in seconds, between points when Enhan |
# |                                            |                          | ced Monitoring metrics are collected for the DB ins |
# |                                            |                          | tance.                                              |
# | monitoring_role_arn                        | text                     | The ARN for the IAM role that permits RDS to send E |
# |                                            |                          | nhanced Monitoring metrics to Amazon CloudWatch Log |
# |                                            |                          | s.                                                  |
# | multi_az                                   | boolean                  | Specifies if the DB instance is a Multi-AZ deployme |
# |                                            |                          | nt.                                                 |
# | nchar_character_set_name                   | text                     | The name of the NCHAR character set for the Oracle  |
# |                                            |                          | DB instance.                                        |
# | option_group_memberships                   | jsonb                    | A list of option group memberships for this DB inst |
# |                                            |                          | ance                                                |
# | partition                                  | text                     | The AWS partition in which the resource is located  |
# |                                            |                          | (aws, aws-cn, or aws-us-gov).                       |
# | pending_maintenance_actions                | jsonb                    | A list that provides details about the pending main |
# |                                            |                          | tenance actions for the resource.                   |
# | performance_insights_enabled               | boolean                  | Specifies whether Performance Insights is enabled f |
# |                                            |                          | or the DB instance, or not.                         |
# | performance_insights_kms_key_id            | text                     | The AWS KMS key identifier for encryption of Perfor |
# |                                            |                          | mance Insights data.                                |
# | performance_insights_retention_period      | bigint                   | The amount of time, in days, to retain Performance  |
# |                                            |                          | Insights data.                                      |
# | port                                       | bigint                   | Specifies the port that the DB instance listens on. |
# | preferred_backup_window                    | text                     | Specifies the daily time range during which automat |
# |                                            |                          | ed backups are created.                             |
# | preferred_maintenance_window               | text                     | Specifies the weekly time range during which system |
# |                                            |                          |  maintenance can occur.                             |
# | processor_features                         | jsonb                    | The number of CPU cores and the number of threads p |
# |                                            |                          | er core for the DB instance class of the DB instanc |
# |                                            |                          | e.                                                  |
# | promotion_tier                             | bigint                   | Specifies the order in which an Aurora Replica is p |
# |                                            |                          | romoted to the primary instance after a failure of  |
# |                                            |                          | the existing primary instance.                      |
# | publicly_accessible                        | boolean                  | Specifies the accessibility options for the DB inst |
# |                                            |                          | ance.                                               |
# | read_replica_db_cluster_identifiers        | jsonb                    | A list of identifiers of Aurora DB clusters to whic |
# |                                            |                          | h the RDS DB instance is replicated as a read repli |
# |                                            |                          | ca.                                                 |
# | read_replica_db_instance_identifiers       | jsonb                    | A list of identifiers of the read replicas associat |
# |                                            |                          | ed with this DB instance.                           |
# | read_replica_source_db_instance_identifier | text                     | Contains the identifier of the source DB instance i |
# |                                            |                          | f this DB instance is a read replica.               |
# | region                                     | text                     | The AWS Region in which the resource is located.    |
# | replica_mode                               | text                     | The mode of an Oracle read replica.                 |
# | resource_id                                | text                     | The AWS Region-unique, immutable identifier for the |
# |                                            |                          |  DB instance.                                       |
# | secondary_availability_zone                | text                     | Specifies the name of the secondary Availability Zo |
# |                                            |                          | ne for a DB instance with multi-AZ support.         |
# | sp_connection_name                         | text                     | Steampipe connection name.                          |
# | sp_ctx                                     | jsonb                    | Steampipe context in JSON form.                     |
# | status                                     | text                     | Specifies the current state of this database.       |
# | status_infos                               | jsonb                    | The status of a read replica.                       |
# | storage_encrypted                          | boolean                  | Specifies whether the DB instance is encrypted, or  |
# |                                            |                          | not.                                                |
# | storage_throughput                         | bigint                   | Specifies the storage throughput for the DB instanc |
# |                                            |                          | e. This setting applies only to the gp3 storage typ |
# |                                            |                          | e.                                                  |
# | storage_type                               | text                     | Specifies the storage type associated with DB insta |
# |                                            |                          | nce.                                                |
# | subnets                                    | jsonb                    | A list of subnet elements.                          |
# | tags                                       | jsonb                    | A map of tags for the resource.                     |
# | tags_src                                   | jsonb                    | A list of tags attached to the DB Instance.         |
# | tde_credential_arn                         | text                     |  The ARN from the key store with which the instance |
# |                                            |                          |  is associated for TDE encryption.                  |
# | timezone                                   | text                     | The time zone of the DB instance.                   |
# | title                                      | text                     | Title of the resource.                              |
# | vpc_id                                     | text                     | Provides the VpcId of the DB subnet group.          |
# | vpc_security_groups                        | jsonb                    | A list of VPC security group elements that the DB i |
# |                                            |                          | nstance belongs to.                                 |
# +--------------------------------------------+--------------------------+-----------------------------------------------------+

steampipe query "
select
  region,
  availability_zone,
  title,
  db_cluster_identifier,
  db_name,
  db_instance_identifier,
  status,
  class,
  allocated_storage as allocated_storage_GiB,
  storage_type,
  iops,
  engine,
  engine_version,
  license_model,
  backup_retention_period,
  account_id,
  sp_connection_name as profile_discovery
from
  ${TABLE_PREFIX}.aws_rds_db_instance;
" --output csv 1>${CSV_DIR}/aws_rds_db_instance.csv 2>&1


#!/bin/sh
# ===========================================================================================================================
# .inspect aws_efs_file_system;
# +----------------------------------+--------------------------+-------------------------------------------------------+
# | column                           | type                     | description                                           |
# +----------------------------------+--------------------------+-------------------------------------------------------+
# | _ctx                             | jsonb                    | Steampipe context in JSON form.                       |
# | account_id                       | text                     | The AWS Account ID in which the resource is located.  |
# | akas                             | jsonb                    | Array of globally unique identifier strings (also kno |
# |                                  |                          | wn as) for the resource.                              |
# | arn                              | text                     | The Amazon Resource Name (ARN) for the EFS file syste |
# |                                  |                          | m.                                                    |
# | automatic_backups                | text                     | Automatic backups use a default backup plan with the  |
# |                                  |                          | AWS Backup recommended settings for automatic backups |
# |                                  |                          | .                                                     |
# | availability_zone_id             | text                     | The unique and consistent identifier of the Availabil |
# |                                  |                          | ity Zone in which the file system is located, and is  |
# |                                  |                          | valid only for One Zone file systems.                 |
# | availability_zone_name           | text                     | Describes the Amazon Web Services Availability Zone i |
# |                                  |                          | n which the file system is located, and is valid only |
# |                                  |                          |  for One Zone file systems.                           |
# | creation_time                    | timestamp with time zone | The time that the file system was created.            |
# | creation_token                   | text                     | The opaque string specified in the request.           |
# | encrypted                        | boolean                  | A Boolean value that, if true, indicates that the fil |
# |                                  |                          | e system is encrypted.                                |
# | file_system_id                   | text                     | The ID of the file system, assigned by Amazon EFS.    |
# | kms_key_id                       | text                     | The ID of an AWS Key Management Service (AWS KMS) cus |
# |                                  |                          | tomer master key (CMK) that was used to protect the e |
# |                                  |                          | ncrypted file system.                                 |
# | life_cycle_state                 | text                     | The lifecycle phase of the file system.               |
# | name                             | text                     | Name of the file system provided by the user.         |
# | number_of_mount_targets          | bigint                   | The current number of mount targets that the file sys |
# |                                  |                          | tem has.                                              |
# | owner_id                         | text                     | The AWS account that created the file system.         |
# | partition                        | text                     | The AWS partition in which the resource is located (a |
# |                                  |                          | ws, aws-cn, or aws-us-gov).                           |
# | performance_mode                 | text                     | The performance mode of the file system.              |
# | policy                           | jsonb                    | The JSON formatted FileSystemPolicy for the EFS file  |
# |                                  |                          | system.                                               |
# | policy_std                       | jsonb                    | Contains the policy in a canonical form for easier se |
# |                                  |                          | arching.                                              |
# | provisioned_throughput_in_mibps  | double precision         | The throughput, measured in MiB/s, that you want to p |
# |                                  |                          | rovision for a file system.                           |
# | region                           | text                     | The AWS Region in which the resource is located.      |
# | replication_overwrite_protection | text                     | The status of the file system's replication overwrite |
# |                                  |                          |  protection.                                          |
# | size_in_bytes                    | jsonb                    | The latest known metered size (in bytes) of data stor |
# |                                  |                          | ed in the file system.                                |
# | sp_connection_name               | text                     | Steampipe connection name.                            |
# | sp_ctx                           | jsonb                    | Steampipe context in JSON form.                       |
# | tags                             | jsonb                    | A map of tags for the resource.                       |
# | tags_src                         | jsonb                    | A list of tags associated with Filesystem.            |
# | throughput_mode                  | text                     | The throughput mode for a file system.                |
# | title                            | text                     | Title of the resource.                                |
# +----------------------------------+--------------------------+-------------------------------------------------------+

steampipe query "
select
  region,
  title,
  file_system_id,
  number_of_mount_targets,
  performance_mode,
  throughput_mode,
  size_in_bytes ->> 'ValueInArchive' as size_bytes_archive,
  size_in_bytes ->> 'ValueInIA' as size_bytes_ia,
  size_in_bytes ->> 'ValueInStandard' as size_bytes_standard,
  account_id,
  sp_connection_name as profile_discovery
from
  aws_efs_file_system
" --output csv 1>${CSV_DIR}/aws-efs-elastic_file_system.csv 2>&1

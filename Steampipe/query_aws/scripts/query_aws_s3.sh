#!/bin/sh
# ===========================================================================================================================
# .inspect aws_s3_bucket;
# +--------------------------------------+--------------------------+----------------------------------------------------------------+
# | column                               | type                     | description                                                    |
# +--------------------------------------+--------------------------+----------------------------------------------------------------+
# | _ctx                                 | jsonb                    | Steampipe context in JSON form.                                |
# | account_id                           | text                     | The AWS Account ID in which the resource is located.           |
# | acl                                  | jsonb                    | The access control list (ACL) of a bucket.                     |
# | akas                                 | jsonb                    | Array of globally unique identifier strings (also known as) fo |
# |                                      |                          | r the resource.                                                |
# | arn                                  | text                     | The ARN of the AWS S3 Bucket.                                  |
# | block_public_acls                    | boolean                  | Specifies whether Amazon S3 should block public access control |
# |                                      |                          |  lists (ACLs) for this bucket and objects in this bucket.      |
# | block_public_policy                  | boolean                  | Specifies whether Amazon S3 should block public bucket policie |
# |                                      |                          | s for this bucket. If TRUE it causes Amazon S3 to reject calls |
# |                                      |                          |  to PUT Bucket policy if the specified bucket policy allows pu |
# |                                      |                          | blic access.                                                   |
# | bucket_policy_is_public              | boolean                  | The policy status for an Amazon S3 bucket, indicating whether  |
# |                                      |                          | the bucket is public.                                          |
# | creation_date                        | timestamp with time zone | The date and time when bucket was created.                     |
# | event_notification_configuration     | jsonb                    | A container for specifying the notification configuration of t |
# |                                      |                          | he bucket. If this element is empty, notifications are turned  |
# |                                      |                          | off for the bucket.                                            |
# | ignore_public_acls                   | boolean                  | Specifies whether Amazon S3 should ignore public ACLs for this |
# |                                      |                          |  bucket and objects in this bucket. Setting this element to TR |
# |                                      |                          | UE causes Amazon S3 to ignore all public ACLs on this bucket a |
# |                                      |                          | nd objects in this bucket.                                     |
# | lifecycle_rules                      | jsonb                    | The lifecycle configuration information of the bucket.         |
# | logging                              | jsonb                    | The logging status of a bucket and the permissions users have  |
# |                                      |                          | to view and modify that status.                                |
# | name                                 | text                     | The user friendly name of the bucket.                          |
# | object_lock_configuration            | jsonb                    | The specified bucket's object lock configuration.              |
# | object_ownership_controls            | jsonb                    | The Ownership Controls for an Amazon S3 bucket.                |
# | partition                            | text                     | The AWS partition in which the resource is located (aws, aws-c |
# |                                      |                          | n, or aws-us-gov).                                             |
# | policy                               | jsonb                    | The resource IAM access document for the bucket.               |
# | policy_std                           | jsonb                    | Contains the policy in a canonical form for easier searching.  |
# | region                               | text                     | The AWS Region in which the resource is located.               |
# | replication                          | jsonb                    | The replication configuration of a bucket.                     |
# | restrict_public_buckets              | boolean                  | Specifies whether Amazon S3 should restrict public bucket poli |
# |                                      |                          | cies for this bucket. Setting this element to TRUE restricts a |
# |                                      |                          | ccess to this bucket to only AWS service principals and author |
# |                                      |                          | ized users within this account if the bucket has a public poli |
# |                                      |                          | cy.                                                            |
# | server_side_encryption_configuration | jsonb                    | The default encryption configuration for an Amazon S3 bucket.  |
# | sp_connection_name                   | text                     | Steampipe connection name.                                     |
# | sp_ctx                               | jsonb                    | Steampipe context in JSON form.                                |
# | tags                                 | jsonb                    | A map of tags for the resource.                                |
# | tags_src                             | jsonb                    | A list of tags assigned to bucket.                             |
# | title                                | text                     | Title of the resource.                                         |
# | versioning_enabled                   | boolean                  | The versioning state of a bucket.                              |
# | versioning_mfa_delete                | boolean                  | The MFA Delete status of the versioning state.                 |
# | website_configuration                | jsonb                    | The website configuration information of the bucket.           |
# +--------------------------------------+--------------------------+----------------------------------------------------------------+


steampipe query "
select
  sp_connection_name as profile_discovery,
  title,
  region,
  account_id
from
  ${TABLE_PREFIX}.aws_s3_bucket;
" --output csv 1>${CSV_DIR}/aws_s3_bucket.csv 2>&1

#!/bin/sh
# ===========================================================================================================================
# .inspect aws_eks_node_group;
# +--------------------+--------------------------+-----------------------------------------------------------------------------+
# | column             | type                     | description                                                                 |
# +--------------------+--------------------------+-----------------------------------------------------------------------------+
# | _ctx               | jsonb                    | Steampipe context in JSON form.                                             |
# | account_id         | text                     | The AWS Account ID in which the resource is located.                        |
# | akas               | jsonb                    | Array of globally unique identifier strings (also known as) for the resourc |
# |                    |                          | e.                                                                          |
# | ami_type           | text                     | The AMI type that was specified in the node group configuration.            |
# | arn                | text                     | The Amazon Resource Name (ARN) associated with the managed node group.      |
# | capacity_type      | text                     | The capacity type of your managed node group.                               |
# | cluster_name       | text                     | The name of the cluster that the managed node group resides in.             |
# | created_at         | timestamp with time zone | The Unix epoch timestamp in seconds for when the managed node group was cre |
# |                    |                          | ated.                                                                       |
# | disk_size          | bigint                   | The disk size in the node group configuration.                              |
# | health             | jsonb                    | The health status of the node group.                                        |
# | instance_types     | jsonb                    | The instance type that is associated with the node group. If the node group |
# |                    |                          |  was deployed with a launch template, then this is null.                    |
# | labels             | jsonb                    | The Kubernetes labels applied to the nodes in the node group.               |
# | launch_template    | jsonb                    | If a launch template was used to create the node group, then this is the la |
# |                    |                          | unch template that was used.                                                |
# | modified_at        | timestamp with time zone | The Unix epoch timestamp in seconds for when the managed node group was las |
# |                    |                          | t modified.                                                                 |
# | node_role          | text                     | The IAM role associated with your node group.                               |
# | nodegroup_name     | text                     | The name associated with an Amazon EKS managed node group.                  |
# | partition          | text                     | The AWS partition in which the resource is located (aws, aws-cn, or aws-us- |
# |                    |                          | gov).                                                                       |
# | region             | text                     | The AWS Region in which the resource is located.                            |
# | release_version    | text                     | If the node group was deployed using a launch template with a custom AMI, t |
# |                    |                          | hen this is the AMI ID that was specified in the launch template. For node  |
# |                    |                          | groups that weren't deployed using a launch template, this is the version o |
# |                    |                          | f the Amazon EKS optimized AMI that the node group was deployed with.       |
# | remote_access      | jsonb                    | The remote access configuration that is associated with the node group. If  |
# |                    |                          | the node group was deployed with a launch template, then this is null.      |
# | resources          | jsonb                    | The resources associated with the node group, such as Auto Scaling groups a |
# |                    |                          | nd security groups for remote access.                                       |
# | scaling_config     | jsonb                    | The scaling configuration details for the Auto Scaling group that is associ |
# |                    |                          | ated with your node group.                                                  |
# | sp_connection_name | text                     | Steampipe connection name.                                                  |
# | sp_ctx             | jsonb                    | Steampipe context in JSON form.                                             |
# | status             | text                     | The current status of the managed node group.                               |
# | subnets            | jsonb                    | The subnets that were specified for the Auto Scaling group that is associat |
# |                    |                          | ed with your node group.                                                    |
# | tags               | jsonb                    | A map of tags for the resource.                                             |
# | taints             | jsonb                    | The Kubernetes taints to be applied to the nodes in the node group when the |
# |                    |                          | y are created.                                                              |
# | title              | text                     | Title of the resource.                                                      |
# | update_config      | jsonb                    | The node group update configuration.                                        |
# | version            | text                     | The Kubernetes version of the managed node group.                           |
# +--------------------+--------------------------+-----------------------------------------------------------------------------+


steampipe query "
select
  region,
  title,
  status,
  cluster_name,
  nodegroup_name,
  scaling_config ->> 'DesiredSize' as scaling_desiredsize,
  scaling_config ->> 'MaxSize' as scaling_maxsize,
  scaling_config ->> 'MinSize' as scaling_minsize,
  ami_type,
  capacity_type,
  release_version,
  version,
  jsonb_array_elements_text( instance_types ) as instance_types,
  disk_size,
  account_id,
  sp_connection_name as profile_discovery
from
  ${TABLE_PREFIX}.aws_eks_node_group;
" --output csv 1>${CSV_DIR}/aws_eks_node_group.csv 2>&1


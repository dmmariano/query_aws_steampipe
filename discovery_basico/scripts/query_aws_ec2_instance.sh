#!/bin/sh
# ===========================================================================================================================
# .inspect aws_ec2_instance;
# +--------------------------------------------+--------------------------+----------------------------------------------+
# | column                                     | type                     | description                                  |
# +--------------------------------------------+--------------------------+----------------------------------------------+
# | _ctx                                       | jsonb                    | Steampipe context in JSON form.              |
# | account_id                                 | text                     | The AWS Account ID in which the resource is  |
# |                                            |                          | located.                                     |
# | akas                                       | jsonb                    | Array of globally unique identifier strings  |
# |                                            |                          | (also known as) for the resource.            |
# | ami_launch_index                           | bigint                   | The AMI launch index, which can be used to f |
# |                                            |                          | ind this instance in the launch group.       |
# | architecture                               | text                     | The architecture of the image.               |
# | arn                                        | text                     | The Amazon Resource Name (ARN) specifying th |
# |                                            |                          | e instance.                                  |
# | block_device_mappings                      | jsonb                    | Block device mapping entries for the instanc |
# |                                            |                          | e.                                           |
# | boot_mode                                  | text                     | The boot mode of the instance.               |
# | capacity_reservation_id                    | text                     | The ID of the Capacity Reservation.          |
# | capacity_reservation_specification         | jsonb                    | Information about the Capacity Reservation t |
# |                                            |                          | argeting option.                             |
# | client_token                               | text                     | The idempotency token you provided when you  |
# |                                            |                          | launched the instance, if applicable.        |
# | cpu_options_core_count                     | bigint                   | The number of CPU cores for the instance.    |
# | cpu_options_threads_per_core               | bigint                   | The number of threads per CPU core.          |
# | current_instance_boot_mode                 | text                     | The boot mode that is used to boot the insta |
# |                                            |                          | nce at launch or start.                      |
# | disable_api_termination                    | boolean                  | If the value is true, instance can't be term |
# |                                            |                          | inated through the Amazon EC2 console, CLI,  |
# |                                            |                          | or API.                                      |
# | ebs_optimized                              | boolean                  | Indicates whether the instance is optimized  |
# |                                            |                          | for Amazon EBS I/O. This optimization provid |
# |                                            |                          | es dedicated throughput to Amazon EBS and an |
# |                                            |                          |  optimized configuration stack to provide op |
# |                                            |                          | timal I/O performance. This optimization isn |
# |                                            |                          | 't available with all instance types.        |
# | elastic_gpu_associations                   | jsonb                    | The Elastic GPU associated with the instance |
# |                                            |                          | .                                            |
# | elastic_inference_accelerator_associations | jsonb                    | The elastic inference accelerator associated |
# |                                            |                          |  with the instance.                          |
# | ena_support                                | boolean                  | Specifies whether enhanced networking with E |
# |                                            |                          | NA is enabled.                               |
# | enclave_options                            | jsonb                    | Indicates whether the instance is enabled fo |
# |                                            |                          | r Amazon Web Services Nitro Enclaves.        |
# | hibernation_options                        | jsonb                    | Indicates whether the instance is enabled fo |
# |                                            |                          | r hibernation.                               |
# | hypervisor                                 | text                     | The hypervisor type of the instance. The val |
# |                                            |                          | ue xen is used for both Xen and Nitro hyperv |
# |                                            |                          | isors.                                       |
# | iam_instance_profile_arn                   | text                     | The Amazon Resource Name (ARN) of IAM instan |
# |                                            |                          | ce profile associated with the instance, if  |
# |                                            |                          | applicable.                                  |
# | iam_instance_profile_id                    | text                     | The ID of the instance profile associated wi |
# |                                            |                          | th the instance, if applicable.              |
# | image_id                                   | text                     | The ID of the AMI used to launch the instanc |
# |                                            |                          | e.                                           |
# | instance_id                                | text                     | The ID of the instance.                      |
# | instance_initiated_shutdown_behavior       | text                     | Indicates whether an instance stops or termi |
# |                                            |                          | nates when you initiate shutdown from the in |
# |                                            |                          | stance (using the operating system command f |
# |                                            |                          | or system shutdown).                         |
# | instance_lifecycle                         | text                     | Indicates whether this is a spot instance or |
# |                                            |                          |  a scheduled instance.                       |
# | instance_state                             | text                     | The state of the instance (pending | running |
# |                                            |                          |  | shutting-down | terminated | stopping | s |
# |                                            |                          | topped).                                     |
# | instance_status                            | jsonb                    | The status of an instance. Instance status i |
# |                                            |                          | ncludes scheduled events, status checks and  |
# |                                            |                          | instance state information.                  |
# | instance_type                              | text                     | The instance type.                           |
# | ipv6_address                               | text                     | The IPv6 address assigned to the instance.   |
# | kernel_id                                  | text                     | The kernel ID                                |
# | key_name                                   | text                     | The name of the key pair, if this instance w |
# |                                            |                          | as launched with an associated key pair.     |
# | launch_template_data                       | jsonb                    | The configuration data of the specified inst |
# |                                            |                          | ance.                                        |
# | launch_time                                | timestamp with time zone | The time the instance was launched.          |
# | licenses                                   | jsonb                    | The license configurations for the instance. |
# | maintenance_options                        | jsonb                    | The metadata options for the instance.       |
# | metadata_options                           | jsonb                    | The metadata options for the instance.       |
# | monitoring_state                           | text                     | Indicates whether detailed monitoring is ena |
# |                                            |                          | bled (disabled | enabled).                   |
# | network_interfaces                         | jsonb                    | The network interfaces for the instance.     |
# | outpost_arn                                | text                     | The Amazon Resource Name (ARN) of the Outpos |
# |                                            |                          | t, if applicable.                            |
# | partition                                  | text                     | The AWS partition in which the resource is l |
# |                                            |                          | ocated (aws, aws-cn, or aws-us-gov).         |
# | placement_affinity                         | text                     | The affinity setting for the instance on the |
# |                                            |                          |  Dedicated Host.                             |
# | placement_availability_zone                | text                     | The Availability Zone of the instance.       |
# | placement_group_id                         | text                     | The ID of the placement group that the insta |
# |                                            |                          | nce is in.                                   |
# | placement_group_name                       | text                     | The name of the placement group the instance |
# |                                            |                          |  is in.                                      |
# | placement_host_id                          | text                     | The ID of the Dedicated Host on which the in |
# |                                            |                          | stance resides.                              |
# | placement_host_resource_group_arn          | text                     | The ARN of the host resource group in which  |
# |                                            |                          | to launch the instances.                     |
# | placement_partition_number                 | bigint                   | The ARN of the host resource group in which  |
# |                                            |                          | to launch the instances.                     |
# | placement_tenancy                          | text                     | The tenancy of the instance (if the instance |
# |                                            |                          |  is running in a VPC). An instance with a te |
# |                                            |                          | nancy of dedicated runs on single-tenant har |
# |                                            |                          | dware.                                       |
# | platform                                   | text                     | The value is 'Windows' for Windows instances |
# |                                            |                          | ; otherwise blank.                           |
# | platform_details                           | text                     | The platform details value for the instance. |
# | private_dns_name                           | text                     | The private DNS hostname name assigned to th |
# |                                            |                          | e instance. This DNS hostname can only be us |
# |                                            |                          | ed inside the Amazon EC2 network. This name  |
# |                                            |                          | is not available until the instance enters t |
# |                                            |                          | he running state.                            |
# | private_dns_name_options                   | jsonb                    | The options for the instance hostname.       |
# | private_ip_address                         | inet                     | The private IPv4 address assigned to the ins |
# |                                            |                          | tance.                                       |
# | product_codes                              | jsonb                    | The product codes attached to this instance, |
# |                                            |                          |  if applicable.                              |
# | public_dns_name                            | text                     | The public DNS name assigned to the instance |
# |                                            |                          | . This name is not available until the insta |
# |                                            |                          | nce enters the running state.                |
# | public_ip_address                          | inet                     | The public IPv4 address, or the Carrier IP a |
# |                                            |                          | ddress assigned to the instance, if applicab |
# |                                            |                          | le.                                          |
# | ram_disk_id                                | text                     | The RAM disk ID.                             |
# | region                                     | text                     | The AWS Region in which the resource is loca |
# |                                            |                          | ted.                                         |
# | root_device_name                           | text                     | The device name of the root device volume (f |
# |                                            |                          | or example, /dev/sda1).                      |
# | root_device_type                           | text                     | The root device type used by the AMI. The AM |
# |                                            |                          | I can use an EBS volume or an instance store |
# |                                            |                          |  volume.                                     |
# | security_groups                            | jsonb                    | The security groups for the instance.        |
# | source_dest_check                          | boolean                  | Specifies whether to enable an instance laun |
# |                                            |                          | ched in a VPC to perform NAT. This controls  |
# |                                            |                          | whether source/destination checking is enabl |
# |                                            |                          | ed on the instance.                          |
# | sp_connection_name                         | text                     | Steampipe connection name.                   |
# | sp_ctx                                     | jsonb                    | Steampipe context in JSON form.              |
# | spot_instance_request_id                   | text                     | If the request is a Spot Instance request, t |
# |                                            |                          | he ID of the request.                        |
# | sriov_net_support                          | text                     | Indicates whether enhanced networking with t |
# |                                            |                          | he Intel 82599 Virtual Function interface is |
# |                                            |                          |  enabled.                                    |
# | state_code                                 | bigint                   | The reason code for the state change.        |
# | state_reason                               | jsonb                    | The reason for the most recent state transit |
# |                                            |                          | ion.                                         |
# | state_transition_reason                    | text                     | The reason for the most recent state transit |
# |                                            |                          | ion.                                         |
# | state_transition_time                      | timestamp with time zone | The date and time, the instance state was la |
# |                                            |                          | st modified.                                 |
# | subnet_id                                  | text                     | The ID of the subnet in which the instance i |
# |                                            |                          | s running.                                   |
# | tags                                       | jsonb                    | A map of tags for the resource.              |
# | tags_src                                   | jsonb                    | A list of tags assigned to the instance.     |
# | title                                      | text                     | Title of the resource.                       |
# | tpm_support                                | text                     | If the instance is configured for NitroTPM s |
# |                                            |                          | upport, the value is v2.0.                   |
# | usage_operation                            | text                     | The usage operation value for the instance.  |
# | usage_operation_update_time                | text                     | The time that the usage operation was last u |
# |                                            |                          | pdated.                                      |
# | user_data                                  | text                     | The user data of the instance.               |
# | virtualization_type                        | text                     | The virtualization type of the instance.     |
# | vpc_id                                     | text                     | The ID of the VPC in which the instance is r |
# |                                            |                          | unning.                                      |
# +--------------------------------------------+--------------------------+----------------------------------------------+

steampipe query "
select
  region,
  placement_availability_zone as az,
  title,
  architecture,
  platform,
  platform_details,
  instance_id,
  instance_state,
  instance_type,
  cpu_options_core_count,
  cpu_options_threads_per_core,
  root_device_type,
  block_device_mappings,
  hypervisor,
  tags,
  virtualization_type,
  account_id,
  key_name,
  sp_connection_name as profile_discovery
from
  ${TABLE_PREFIX}.aws_ec2_instance;
" --output csv 1>${CSV_DIR}/aws_ec2_instance.csv 2>&1


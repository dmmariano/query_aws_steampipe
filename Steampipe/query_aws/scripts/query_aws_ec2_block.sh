#!/bin/sh

steampipe query "
select
  i.title,
  i.instance_type           as instance_type,
  i.platform_details        as operating_system,
  coalesce(sum(v.size), 0)  as total_volume_size_gb,
   i.instance_state,
   i.tags
from
  ${TABLE_PREFIX}.aws_ec2_instance i
left join
  ${TABLE_PREFIX}.aws_ebs_volume v
    on exists (
      select 1
      from jsonb_array_elements(v.attachments) as a
      where a ->> 'InstanceId' = i.instance_id
    )
group by
  i.title,
  i.instance_type,
  i.platform_details,
  i.tags,
  i.instance_state
order by
  i.title;
  " --output csv 1>${CSV_DIR}/aws_ec2_instance_block.csv 2>&1
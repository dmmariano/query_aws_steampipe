#!/bin/sh
# ===========================================================================================================================
# .inspect aws_cost_by_region_monthly
# +---------------------------+--------------------------+---------------------------------------------------+
# | column                    | type                     | description                                       |
# +---------------------------+--------------------------+---------------------------------------------------+
# | _ctx                      | jsonb                    | Steampipe context in JSON form.                   |
# | amortized_cost_amount     | double precision         | This cost metric reflects the effective cost of t |
# |                           |                          | he upfront and monthly reservation fees spread ac |
# |                           |                          | ross the billing period. By default, Cost Explore |
# |                           |                          | r shows the fees for Reserved Instances as a spik |
# |                           |                          | e on the day that you're charged, but if you choo |
# |                           |                          | se to show costs as amortized costs, the costs ar |
# |                           |                          | e amortized over the billing period. This means t |
# |                           |                          | hat the costs are broken out into the effective d |
# |                           |                          | aily rate. AWS estimates your amortized costs by  |
# |                           |                          | combining your unblended costs with the amortized |
# |                           |                          |  portion of your upfront and recurring reservatio |
# |                           |                          | n fees.                                           |
# | amortized_cost_unit       | text                     | Unit type for amortized costs.                    |
# | blended_cost_amount       | double precision         | This cost metric reflects the average cost of usa |
# |                           |                          | ge across the consolidated billing family. If you |
# |                           |                          |  use the consolidated billing feature in AWS Orga |
# |                           |                          | nizations, you can view costs using blended rates |
# |                           |                          | .                                                 |
# | blended_cost_unit         | text                     | Unit type for blended costs.                      |
# | estimated                 | boolean                  | Whether the result is estimated.                  |
# | net_amortized_cost_amount | double precision         | This cost metric amortizes the upfront and monthl |
# |                           |                          | y reservation fees while including discounts such |
# |                           |                          |  as RI volume discounts.                          |
# | net_amortized_cost_unit   | text                     | Unit type for net amortized costs.                |
# | net_unblended_cost_amount | double precision         | This cost metric reflects the unblended cost afte |
# |                           |                          | r discounts.                                      |
# | net_unblended_cost_unit   | text                     | Unit type for net unblended costs.                |
# | normalized_usage_amount   | double precision         | The amount of usage that you incurred, in normali |
# |                           |                          | zed units, for size-flexible RIs. The NormalizedU |
# |                           |                          | sageAmount is equal to UsageAmount multiplied by  |
# |                           |                          | NormalizationFactor.                              |
# | normalized_usage_unit     | text                     | Unit type for normalized usage.                   |
# | period_end                | timestamp with time zone | End timestamp for this cost metric.               |
# | period_start              | timestamp with time zone | Start timestamp for this cost metric.             |
# | region                    | text                     | The name of the AWS region.                       |
# | sp_connection_name        | text                     | Steampipe connection name.                        |
# | sp_ctx                    | jsonb                    | Steampipe context in JSON form.                   |
# | unblended_cost_amount     | double precision         | Unblended costs represent your usage costs on the |
# |                           |                          |  day they are charged to you. In finance terms, t |
# |                           |                          | hey represent your costs on a cash basis of accou |
# |                           |                          | nting.                                            |
# | unblended_cost_unit       | text                     | Unit type for unblended costs.                    |
# | usage_quantity_amount     | double precision         | The amount of usage that you incurred. NOTE: If y |
# |                           |                          | ou return the UsageQuantity metric, the service a |
# |                           |                          | ggregates all usage numbers without taking into a |
# |                           |                          | ccount the units. For example, if you aggregate u |
# |                           |                          | sageQuantity across all of Amazon EC2, the result |
# |                           |                          | s aren't meaningful because Amazon EC2 compute ho |
# |                           |                          | urs and data transfer are measured in different u |
# |                           |                          | nits (for example, hours vs. GB).                 |
# | usage_quantity_unit       | text                     | Unit type for usage quantity.                     |
# +---------------------------+--------------------------+---------------------------------------------------+

steampipe query "
select
  sp_connection_name as profile_discovery,
  estimated,
  period_start,
  period_end,
  region,
  usage_quantity_amount,
  usage_quantity_unit,
  net_unblended_cost_amount,
  net_unblended_cost_unit,
  net_amortized_cost_amount,
  net_amortized_cost_unit,
  blended_cost_amount,
  blended_cost_unit,
  unblended_cost_amount,
  unblended_cost_unit,
  amortized_cost_amount,
  amortized_cost_unit,
  normalized_usage_amount,
  normalized_usage_unit
from
  ${TABLE_PREFIX}.aws_cost_by_region_monthly
" --output csv 1> ${CSV_DIR}/aws_cost_by_region_monthly.csv 2>&1

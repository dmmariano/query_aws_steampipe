#!/bin/sh
# ===========================================================================================================================
# .inspect aws_cost_by_service_usage_type_monthly
# +---------------------------+--------------------------+---------------------------------------------------------------------+
# | column                    | type                     | description                                                         |
# +---------------------------+--------------------------+---------------------------------------------------------------------+
# | _ctx                      | jsonb                    | Steampipe context in JSON form.                                     |
# | account_id                | text                     | The AWS Account ID in which the resource is located.                |
# | amortized_cost_amount     | double precision         | This cost metric reflects the effective cost of the upfront and mon |
# |                           |                          | thly reservation fees spread across the billing period. By default, |
# |                           |                          |  Cost Explorer shows the fees for Reserved Instances as a spike on  |
# |                           |                          | the day that you're charged, but if you choose to show costs as amo |
# |                           |                          | rtized costs, the costs are amortized over the billing period. This |
# |                           |                          |  means that the costs are broken out into the effective daily rate. |
# |                           |                          |  AWS estimates your amortized costs by combining your unblended cos |
# |                           |                          | ts with the amortized portion of your upfront and recurring reserva |
# |                           |                          | tion fees.                                                          |
# | amortized_cost_unit       | text                     | Unit type for amortized costs.                                      |
# | blended_cost_amount       | double precision         | This cost metric reflects the average cost of usage across the cons |
# |                           |                          | olidated billing family. If you use the consolidated billing featur |
# |                           |                          | e in AWS Organizations, you can view costs using blended rates.     |
# | blended_cost_unit         | text                     | Unit type for blended costs.                                        |
# | estimated                 | boolean                  | Whether the result is estimated.                                    |
# | net_amortized_cost_amount | double precision         | This cost metric amortizes the upfront and monthly reservation fees |
# |                           |                          |  while including discounts such as RI volume discounts.             |
# | net_amortized_cost_unit   | text                     | Unit type for net amortized costs.                                  |
# | net_unblended_cost_amount | double precision         | This cost metric reflects the unblended cost after discounts.       |
# | net_unblended_cost_unit   | text                     | Unit type for net unblended costs.                                  |
# | normalized_usage_amount   | double precision         | The amount of usage that you incurred, in normalized units, for siz |
# |                           |                          | e-flexible RIs. The NormalizedUsageAmount is equal to UsageAmount m |
# |                           |                          | ultiplied by NormalizationFactor.                                   |
# | normalized_usage_unit     | text                     | Unit type for normalized usage.                                     |
# | partition                 | text                     | The AWS partition in which the resource is located (aws, aws-cn, or |
# |                           |                          |  aws-us-gov).                                                       |
# | period_end                | timestamp with time zone | End timestamp for this cost metric.                                 |
# | period_start              | timestamp with time zone | Start timestamp for this cost metric.                               |
# | region                    | text                     | The AWS Region in which the resource is located.                    |
# | service                   | text                     | The name of the AWS service.                                        |
# | sp_connection_name        | text                     | Steampipe connection name.                                          |
# | sp_ctx                    | jsonb                    | Steampipe context in JSON form.                                     |
# | unblended_cost_amount     | double precision         | Unblended costs represent your usage costs on the day they are char |
# |                           |                          | ged to you. In finance terms, they represent your costs on a cash b |
# |                           |                          | asis of accounting.                                                 |
# | unblended_cost_unit       | text                     | Unit type for unblended costs.                                      |
# | usage_quantity_amount     | double precision         | The amount of usage that you incurred. NOTE: If you return the Usag |
# |                           |                          | eQuantity metric, the service aggregates all usage numbers without  |
# |                           |                          | taking into account the units. For example, if you aggregate usageQ |
# |                           |                          | uantity across all of Amazon EC2, the results aren't meaningful bec |
# |                           |                          | ause Amazon EC2 compute hours and data transfer are measured in dif |
# |                           |                          | ferent units (for example, hours vs. GB).                           |
# | usage_quantity_unit       | text                     | Unit type for usage quantity.                                       |
# | usage_type                | text                     | The usage type of this metric.                                      |
# +---------------------------+--------------------------+---------------------------------------------------------------------+

steampipe query "
select
  account_id,
  sp_connection_name as profile_discovery,
  estimated,
  period_start,
  period_end,
  region,
  service,
  usage_type,
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
  ${TABLE_PREFIX}.aws_cost_by_service_usage_type_monthly
" --output csv 1>${CSV_DIR}/aws_cost_by_service_usage_type_monthly.csv 2>&1


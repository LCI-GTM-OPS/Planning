--Future state columns in Anaplan--

SELECT *
FROM u_lmssalesops.dim_planning_master
WHERE half_begin = DATE '2025-07-01'
  --  AND market_crm_account_id IN ('KR_0016000000KOgPVAA1')
;

---------------------------------------------------------------------------------

--Join to Sliced bread--

SELECT

                case when planning.tier is null then 'OSO' else planning.tier end as tier,

                round(sum(case when sb.event_date BETWEEN '2024-07-01' AND '2024-09-30' then sb.recognized_amount_usd_current_rate end),2) as recognized_amount_usd_current_rate_fy25q1,

                round(sum(case when sb.event_date BETWEEN '2024-10-01' AND '2024-12-31' then sb.recognized_amount_usd_current_rate end),2) as recognized_amount_usd_current_rate_fy25q2,

                round(sum(case when sb.event_date BETWEEN '2025-01-01' AND '2025-03-31' then sb.recognized_amount_usd_current_rate end),2) as recognized_amount_usd_current_rate_fy25q3

from foundation_lms_mp.agg_f_sas_campaign_summary sb

left outer join u_lmssalesops.dim_planning_master planning ON 1=1

                AND sb.crm_market = planning.market

                AND sb.crm_account_id = planning.crm_account_id

                AND planning.half_begin = date('2025-07-01')

where sb.event_date BETWEEN '2024-07-01' AND '2025-06-30'

group by 1;

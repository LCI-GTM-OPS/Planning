SET SESSION li_authorization_user = 'lmssalesops';  

/*
## Summary
Query to pull SlicedBread revenue while including online and IO revcollab. This query contains the main relevant fields one would need to map post-revcollab delivery. Of course, additional joins and modifications can be made to serve different business use-cases.

Associated JIRA: https://jira01.corp.linkedin.com:8443/browse/LMS-9751

### _Important Note_

> Applying IO Rev Collabs to delivery in Sliced Bread is NOT our recommended approach to calculate IO revenue. Instead, as reflected in Agg_Named_Delivery (and thus in Crediting processes), we read from the Salesforce CLIS records directly which include opportunity splits that live directly in SFDC, as well as any BNR adjustments uploaded by RevOps.
*/

WITH rev_collab_temp AS (
	SELECT 
		  	  rc.quarter_begin
		  ,   rc.is_complete_deal_source_transfer
		  ,   rc.is_multiple_market_split
		  ,   rc.for_ultimate_parent
		  ,   rc.account_id
		  ,   rc.opportunity_id
		  ,   rc.cmt_advertiser_id
		  ,   rc.market
		  ,   rc.geo_region
		  ,   rc.split_percent_decimal AS split_percent
		  ,   dbu.book_owner_id AS rep_id   
		  ,   dbu.book_user_name AS rep_name
		  ,   dbu.book_user_rep_region AS rep_region
	FROM u_lmssalesops.dim_rev_collab_for_and rc
	LEFT JOIN u_lmssalesops.dim_book_user dbu ON dbu.book_name = rc.book_name
		AND dbu.book_user_role = 'MS_Account Executive'
	WHERE 1=1
		  AND NOT REGEXP_LIKE(LOWER(rc.account_id), 'account not')
          AND (rc.cmt_advertiser_id <> -9 OR rc.opportunity_id IS NOT NULL)
)
, sb_base as (
    SELECT
            sb.event_date
        ,   sb.advertiser_id
		,   sb.crm_opportunity_id
        ,   sb.crm_geo_region
        ,   sb.crm_market
        ,   sb.crm_rep_id
        ,   sb.crm_rep_name
        ,   sb.crm_rep_region
        ,   sb.crm_account_id
        ,   sb.product_category_type
        ,   sb.delivery_currency
        ,   sb.deal_source
		,   SUM(sb.recognized_amount_local)            AS recognized_amount_local
        ,   SUM(sb.recognized_amount_usd_planned_rate) AS recognized_amount_usd_planned_rate	
	FROM foundation_lms_mp.agg_f_sas_campaign_summary sb
	GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12
)
    SELECT
            sb.event_date
        ,   sb.advertiser_id
		,   sb.crm_opportunity_id
            -- If there is a revenue collaboration for the default market 
            -- or no revenue collaboration at all, use Sliced Bread mapping        
        ,   IF(rc.market = sb.crm_market OR rc.market IS NULL, sb.crm_geo_region, rc.geo_region) AS geo_region
        ,   IF(rc.market = sb.crm_market OR rc.market IS NULL, sb.crm_market, rc.market) AS market
        ,   IF(rc.market = sb.crm_market OR rc.market IS NULL, sb.crm_rep_id, rc.rep_id) AS rep_id
        ,   IF(rc.market = sb.crm_market OR rc.market IS NULL, sb.crm_rep_name, rc.rep_name) AS rep_name
        ,   IF(rc.market = sb.crm_market OR rc.market IS NULL, sb.crm_rep_region, rc.rep_region) AS rep_region
        ,   sb.crm_account_id
        ,   sb.product_category_type
        ,   sb.delivery_currency
        ,   sb.deal_source
        ,   sb.recognized_amount_local * COALESCE(rc.split_percent, 1) AS recognized_amount_local
        ,   sb.recognized_amount_usd_planned_rate * COALESCE(rc.split_percent, 1) AS recognized_amount_usd_planned_rate
    FROM sb_base sb
    LEFT JOIN rev_collab_temp rc 
        ON (sb.advertiser_id = rc.cmt_advertiser_id OR sb.crm_opportunity_id = rc.opportunity_id)
        AND NOT (rc.split_percent = 0 AND rc.rep_id IS NULL)
		AND date_trunc('quarter', date(sb.event_date)) = rc.quarter_begin
		
	WHERE 1=1
	--AND sb.crm_rep_region LIKE 'LMS%AP%ESG%'
	--AND AC.ultimate_parent_sfdc_accountid IN ('0016000000S1D2LAAV') --LSEG
	--AND AC.ultimate_parent_sfdc_accountid IN ('0016000000ShawhAAB')
	--AND crm_market IN ('UK','SG') -- LSEG
	--AND SB.crm_account_id IN ('0016Q00001xXBD6QAO')
	AND SB.advertiser_id IN (508544164, 502305371, 506303124)
	--AND SB.crm_opportunity_id IN ()
	--AND SB.campaign_id IN

;

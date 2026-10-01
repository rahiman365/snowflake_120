
-- 1.	In	Snowsight,	go	to	Admin	→	Warehouses.	Note	the	default	
COMPUTE_WH .
3.	Go	to	Admin	→	Accounts	and	record:	Account	edition,	Region,	Cloud	provider.
4.	Open	a	new	SQL	Worksheet	and	run:
SELECT	CURRENT_VERSION();
SELECT	CURRENT_ACCOUNT(),	CURRENT_REGION(),	CURRENT_ORGANIZATION_NAME();
SELECT	CURRENT_WAREHOUSE(),	CURRENT_ROLE(),	CURRENT_USER();
5.	Screenshot	or	note	the	output	—	this	becomes	your	“account	fact	sheet”	for	the	rest	of	the	course.
Exercise	1.2	—	First	warehouse	&	first	query--	Create	a	small	warehouse	dedicated	to	this	course
CREATE	WAREHOUSE	IF	NOT	EXISTS	learn_wh
WAREHOUSE_SIZE	=	'XSMALL'
AUTO_SUSPEND	=	60										
AUTO_RESUME	=	TRUE
INITIALLY_SUSPENDED	=	TRUE;
USE	WAREHOUSE	learn_wh;--	suspend	after	60	seconds	idle--	Snowflake	ships	sample	data	-	explore	it
USE	DATABASE	SNOWFLAKE_SAMPLE_DATA;
USE	SCHEMA	TPCH_SF1;
SELECT	*	FROM	CUSTOMER	LIMIT	10;
SELECT	c_mktsegment,	COUNT(*)	AS	customer_count
FROM	CUSTOMER
GROUP	BY	c_mktsegment
ORDER	BY	customer_count	DESC;
Note	the	warehouse	spin-up	time	(a	few	seconds)	on	first	query,	and	how	the	second	query	on	the	same
warehouse	is	near-instant.

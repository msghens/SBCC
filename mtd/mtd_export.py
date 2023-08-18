#!/usr/bin/env python
from loguru import logger
import sqlalchemy as db
import sqlalchemy.engine.url
from pathlib import Path
import os
import sys
import csv
import requests

#import smtplib
#from email.message import EmailMessage

#Setup TNS_ADMIN for Oracle Wallet
os.environ['TNS_ADMIN'] = '/u04/ise/sbccise'

# logger.info("Update Attributes")
# url = db.engine.url.URL('oracle+cx_oracle', username='/@DB_PROD')
# logger.info(url)
# engine = db.create_engine(url,max_identifier_length=128)
# connection = engine.raw_connection()
# try:
	
	# soaterm = 'szf_get_this_soaterm'
	# cursor = connection.cursor()
	# cursor.callproc("sbcc.szp_add_mtdb_attr", [202230])
	# #results = list(cursor.fetchall())
	# cursor.close()
	# connection.commit()
# finally:
	# connection.close()

# logger.info(f"Added attributes")
# sys.exit("Stop!")

sql = '''
WITH terms AS (
				-- select stvterm_code as term_code from stvterm where 
				-- stvterm_code not in ('000000','999999')
				--MOD07
				--and sysdate between stvterm_start_date - 8 and stvterm_end_date
				--MOD10
    SELECT
        "mtd_term_code" AS term_code
    FROM
        sbcc_rptng_bb.gzb_mtd_terms
    WHERE
        sysdate BETWEEN "mtd_term_start_date" AND "mtd_term_end_date"
)
SELECT
    '721'
    || substr(cardnum, - 8, 8)
    ||
        CASE
            WHEN issue_number = '00' THEN
                '01'
            ELSE
                issue_number
        END
    AS cardnumber
FROM
         sgrsatt left
    INNER JOIN sbcc_rptng_bb.gzv_card ON gzf_get_pidm('K'
                                                      || substr(cardnum, - 8, 8)) = sgrsatt_pidm
WHERE
        sgrsatt_atts_code = 'MTDB'
    AND sgrsatt_term_code_eff IN (
        SELECT
            terms.term_code
        FROM
            terms
    )
UNION
SELECT
    '721'
    || substr(cardnum, - 8, 8)
    ||
        CASE
            WHEN issue_number = '00' THEN
                '01'
            ELSE
                issue_number
        END
    AS cardnumber
FROM
         sbcc_rptng_bb.gzb_mtd_whtlst left
    INNER JOIN sbcc_rptng_bb.gzv_card ON 'K'
                                         || substr(cardnum, - 8, 8) = knum
'''
sql = '''
WITH terms AS (
	SELECT
		"mtd_term_code" AS term_code
	FROM
		sbcc_rptng_bb.gzb_mtd_terms
	WHERE
		sysdate BETWEEN "mtd_term_start_date" AND "mtd_term_end_date"
), paid_tbus AS (
	SELECT
		substr(gzf_get_id(tbraccd_pidm), 2, 9) AS paid_tbus
	FROM
			 tbraccd
		JOIN terms ON 1 = 1
	WHERE
		tbraccd_term_code IN (
			SELECT
				terms.term_code
			FROM
				terms
		)
		AND tbraccd_detail_code = 'TBUS'
	GROUP BY
		tbraccd_pidm,TBRACCD_TERM_CODE
	HAVING
		SUM(tbraccd_amount) > 0
)
SELECT
	'721'
	|| lpad(cardnumber, 8, '0')
	||
		CASE
			WHEN issue_number = '00' THEN
				'01'
			ELSE
				issue_number
		END
	AS cardnumber
FROM
	sbcc_rptng_bb.gzv_card
WHERE
	lpad(cardnumber, 8, '0') IN (
		SELECT
			paid_tbus
		FROM
			paid_tbus
	)
'''

logger.info("Connecting to banner")
try:
	url = db.engine.url.URL('oracle+cx_oracle', username='/@ISE_PROD')
	logger.info(url)
	engine = db.create_engine(url,max_identifier_length=128)
	con = engine.connect()

	# No commit as you don-t need to commit DDL.
	
	outpt = con.execute(sql)
	#directList = [dict(row.items()) for row in outpt]
except Exception as e:
	logger.error("DB Error")
	logger.error(f'{e}')
	con.close()
	engine.dispose()
	sys.exit('DB Error')
	
logger.info('Create mtd file')

cardno = list()
cardno = [r[0] for r in outpt]
# logger.info(f"{cardno}")
logger.info('update history table')
insert_to_tbl_stmt = f"INSERT INTO SBCC_RPTNG_BB.GZB_MTD_HISTORY VALUES  (sysdate,:1)"
# con.executemanny(insert_to_tbl_stmt,i)
for i in cardno:
	con.execute(insert_to_tbl_stmt,i)
    # print(f'{i}')
    # logger.info(f'{i}')
# con.commit()


# con.close()
# engine.dispose()
# sys.exit('YEA')
logger.info("Write whitelist")
#convert to list of lists
cardno = list(map(lambda x:[x], cardno))
with open('/tmp/mtdwhite.txt', 'w') as csvfile: 
	outcsv = csv.writer(csvfile)
	outcsv.writerows(cardno)


logger.info('Close Connection')    
con.close()
engine.dispose()

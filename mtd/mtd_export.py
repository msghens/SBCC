#!/usr/bin/env python
from loguru import logger
import sqlalchemy as db
import sqlalchemy.engine.url
from pathlib import Path
import os
import sys
import csv
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
), cr_student_oc AS (
	SELECT
		substr(gzf_get_id(sfrstcr_pidm), 2, 9) AS cr_student_oc
	FROM
			 sfrstcr
		INNER JOIN stvrsts ON sfrstcr_rsts_code = stvrsts_code
							  AND stvrsts_incl_sect_enrl = 'Y'
		LEFT OUTER JOIN ssbsect ON ( ssbsect_term_code = sfrstcr_term_code
									 AND ssbsect_crn = sfrstcr_crn )
	WHERE
			ssbsect_camp_code = 1
		AND sfrstcr_levl_code = 'CR'
		AND sfrstcr_term_code IN (
			SELECT
				terms.term_code
			FROM
				terms
		)
	GROUP BY
		sfrstcr_pidm
	HAVING
		SUM(sfrstcr_credit_hr) >= 0.5
), cr_student AS (
	SELECT
		substr(gzf_get_id(sfrstcr_pidm), 2, 9) AS cr_student
	FROM
			 sfrstcr
		INNER JOIN stvrsts ON sfrstcr_rsts_code = stvrsts_code
							  AND stvrsts_incl_sect_enrl = 'Y'
		LEFT OUTER JOIN ssbsect ON ( ssbsect_term_code = sfrstcr_term_code
									 AND ssbsect_crn = sfrstcr_crn )
	WHERE
			ssbsect_camp_code <> 6
		AND sfrstcr_levl_code = 'CR'
		AND sfrstcr_term_code IN (
			SELECT
				terms.term_code
			FROM
				terms
		)
	GROUP BY
		sfrstcr_pidm
	HAVING
		SUM(sfrstcr_credit_hr) >= 0.5
), in_district AS (
	SELECT
		substr(gzf_get_id(spraddr_pidm), 2, 9) AS in_district
	FROM
		spraddr
	WHERE
		spraddr_atyp_code IN (
			'MA',
			'PR'
		)
		AND trunc(sysdate) BETWEEN nvl(trunc(spraddr_from_date), trunc(sysdate)) AND nvl(trunc(spraddr_to_date), trunc(sysdate))
		AND substr(spraddr_zip, 1, 5) IN (
			'93101',
			'93102',
			'93103',
			'93105',
			'93106',
			'93107',
			'93108',
			'93109',
			'93110',
			'93111',
			'93116',
			'93117',
			'93118',
			'93013',
			'93014',
			'93150',
			'93120',
			'93121',
			'93130',
			'93140',
			'93160',
			'93190',
			'93067'
		)
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
		tbraccd_pidm
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
			in_district
		FROM
			in_district
	)
	AND lpad(cardnumber, 8, '0') IN (
		SELECT
			cr_student
		FROM
			cr_student
	)
--    AND issue_number <> '00'
UNION
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
			cr_student_oc
		FROM
			cr_student_oc
	)
UNION
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
	# directList = [dict(row.items()) for row in outpt]
except Exception as e:
	logger.error("DB Error")
	logger.error(f'{e}')
	sys.exit('DB Error')
	
logger.info('Create mtd file')



with open('/tmp/mtdwhite.txt', 'w') as csvfile: 
	outcsv = csv.writer(csvfile)
	outcsv.writerows(outpt)

logger.info('Close Connection')    
con.close()
engine.dispose()

# logger.info('mail to to people')

# with open('/tmp/mtdwhite.txt') as fp:
	#Create a text/plain message
	# msg = EmailMessage()
	# msg.set_content(fp.read())


# msg['Subject'] = f"Tommorrow's MTD Whitelist"
# msg['From'] = "mghens@sbcc.edu"
# msg['To'] =  "msghens@gmail.com,mghens@sbcc.edu"


#Send the message via our own SMTP server.
# s = smtplib.SMTP('prelay.sbcc.edu')
# s.send_message(msg)
# s.quit()

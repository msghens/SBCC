--FIN 031

SELECT
    d.fund                            AS "Fund",
    d.farinva_seq_num,
    h.fabinvh_code,
    fabinck_check_num                 AS chk_number,
    fabchks_check_date                AS check_date,
    fabchks_cancel_ind                AS check_status,
    fabchks_cancel_date               AS void_date,
    fs_check_amt                      AS chk_check_amount,
    totals.bank_sum                   AS bank_totals,
    totals.bank_acct_name             AS bank_account_name,
    'na'                              AS checkrun_run,
    f_getspridenid(fabinvh_vend_pidm) AS vendor_number,
    CASE
        WHEN initcap(d.farinvc_comm_desc) LIKE 'Refund And/Or Financial Aid%' THEN
            'Student Refund And/Or Financial Aid'
        WHEN initcap(d.farinvc_comm_desc) = 'Parent Plus Refund' THEN
            'Student Refund And/Or Financial Aid'
        ELSE
            CASE
                WHEN fw_format_name(h.pidm, 'FMIL') LIKE 'NAME NOT FOUND%' THEN
                        h.fabinvh_one_time_vend_name
                ELSE
                    fw_format_name(h.pidm, 'FMIL')
            END
    END                               AS vendor_name,
    ' '                               AS address,
    fabchks_check_date                AS creation_date,
    h.fabinvh_code                    AS inv_chk_number,
    decode(fabinvh_cr_memo_ind, 'Y', - 1, 1) *
    CASE
        WHEN fabinvh_single_acctg_ind = 'N' THEN
                round(coalesce(d.farinva_appr_amt, 0) * coalesce(d.farinva_appr_amt_pct, 0) / 100,
                      2)
        ELSE
            round(coalesce(d.farinvc_appr_qty, 0) * coalesce(d.farinvc_appr_unit_price, 0),
                  2) + coalesce(farinvc_tax_amt, 0) + coalesce(farinvc_addl_chrg_amt, 0) - coalesce(farinvc_disc_amt, 0)
    END
    AS inv_amt,
    initcap(d.farinvc_comm_desc)      AS inv_description
FROM
         fvq_fabchks_paymnt_transaction
    JOIN fvq_fabinvh_fabinck_pt h ON fabchks_check_num = h.fabinck_check_num
    JOIN (
        SELECT
            CASE
                WHEN substr(farinva_fund_code, 1, 2) = '11' THEN
                    'Unrestricted General Fund'
                WHEN substr(farinva_fund_code, 1, 2) = '12' THEN
                    'Restricted General Fund'
                WHEN substr(farinva_fund_code, 1, 1) = '2'  THEN
                    'Debt Service Funds'
                WHEN substr(farinva_fund_code, 1, 1) = '3'  THEN
                    'Special Revenue Funds'
                WHEN substr(farinva_fund_code, 1, 1) = '4'  THEN
                    'Capital Projects Funds'
                WHEN substr(farinva_fund_code, 1, 1) = '5'  THEN
                    'Enterprise Funds'
                WHEN substr(farinva_fund_code, 1, 1) = '6'  THEN
                    'Internal Service Fund'
                WHEN substr(farinva_fund_code, 1, 1) = '7'  THEN
                    'Trust Funds'
                WHEN substr(farinva_fund_code, 1, 2) = '81' THEN
                    'Agency Funds'
                ELSE
                    farinva_fund_code
            END fund,
            fvq_invoice_documents.*
        FROM
            fvq_invoice_documents
    )                      d ON h.fabinvh_code = d.fabinvh_code
    JOIN (
        SELECT
            fund                 fs_fund,
            fabinck_check_num    fs_fabinck_check_num,
            SUM(fabinck_net_amt) fs_check_amt
        FROM
                 fvq_fabinvh_fabinck_pt
            JOIN (
                SELECT
                    CASE
                        WHEN substr(farinva_fund_code, 1, 2) = '11' THEN
                            'Unrestricted General Fund'
                        WHEN substr(farinva_fund_code, 1, 2) = '12' THEN
                            'Restricted General Fund'
                        WHEN substr(farinva_fund_code, 1, 1) = '2'  THEN
                            'Debt Service Funds'
                        WHEN substr(farinva_fund_code, 1, 1) = '3'  THEN
                            'Special Revenue Funds'
                        WHEN substr(farinva_fund_code, 1, 1) = '4'  THEN
                            'Capital Projects Funds'
                        WHEN substr(farinva_fund_code, 1, 1) = '5'  THEN
                            'Enterprise Funds'
                        WHEN substr(farinva_fund_code, 1, 1) = '6'  THEN
                            'Internal Service Fund'
                        WHEN substr(farinva_fund_code, 1, 1) = '7'  THEN
                            'Trust Funds'
                        WHEN substr(farinva_fund_code, 1, 2) = '81' THEN
                            'Agency Funds'
                        ELSE
                            farinva_fund_code
                    END fund,
                    farinva_invh_code
                FROM
                    fvq_farinva_invoice
            ) ON fabinvh_code = farinva_invh_code
        GROUP BY
            fund,
            fabinck_check_num
    ) ON fs_fund = d.fund
         AND fs_fabinck_check_num = fabinck_check_num
    JOIN (
        SELECT
            SUM(fabchks_check_amt) bank_sum,
            bank_code,
            bank_acct_name
        FROM
                 fvq_fabchks_paymnt_transaction
            JOIN gvq_bank_validation_guid ON bank_code = fabchks_bank_code
        WHERE
            fabchks_cancel_ind IS NULL
            AND fabchks_check_date BETWEEN :d_from AND :d_to
        GROUP BY
            bank_code,
            bank_acct_name
    )                      totals ON fabchks_bank_code = bank_code
WHERE
    fabchks_check_date BETWEEN :d_from AND :d_to
    AND d.farinva_fund_code NOT LIKE '71%'
    AND d.farinva_fund_code NOT LIKE '72%'
    AND d.farinva_fund_code NOT LIKE '74%'
    AND d.farinva_fund_code NOT LIKE '75%'
    AND d.farinva_fund_code NOT LIKE '77%'
    AND d.farinva_fund_code NOT LIKE '79%'
    AND d.farinva_fund_code NOT LIKE '81%'
    AND h.fabinvh_code NOT LIKE 'S%'
    AND initcap(d.farinvc_comm_desc) NOT LIKE 'Refund And/Or Financial Aid%'
ORDER BY
    d.farinva_fund_code,
    totals.bank_acct_name,
    fabinck_check_num,
    inv_amt

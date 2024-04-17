------------------------
From Baseline View
-----------------------

SELECT
    gzf_get_id(fh.pidm)                             vendor_id,
    ''                                              remi_id,
    coalesce(gzf_format_name(fh.pidm, 'FL'),
             initcap(fabinvh_one_time_vend_name))   merchant_name,
    initcap(address_line1)                          address,
    initcap(address_line2)                          address_2nd,
    initcap(address_cntry_locality)                 city,
    address_cntry_postal_code                       postal_code,
    stvstat_code                                    stvstastate_code,
    coalesce(decode(address_country, '01', 'US', address_country),
             'US')                                  country,
    to_char(SUM(fabchks_check_amt),
            '9999999.99')                           total_spend,
    'USD'                                           payment_currency,
    LISTAGG(DISTINCT decode(instr(fabchks_check_num, '!', 1, 1),
                            1,
                            'ACH',
                            'Check'),
                     '; ') WITHIN GROUP(
    ORDER BY
        gzf_get_id(fh.pidm)
    )                                               payment_type,
    to_char(SUM(fabchks_check_amt),
            '9999999.99')                           total_currency,
    COUNT(fabchks_check_num)                        number_of_checks,
    coalesce(ftvdisc_desc, 'Net 30 days')           payment_terms,
    MAX(fabchks_check_date)                         last_date_paid,
    contact                                         contact_name,
    phone_area
    || ' '
    || phone_number
    || nvl2(phone_ext, ' Ext: ' || phone_ext, NULL) phone,
    coalesce(gzf_email_addr(fh.pidm, 'VNDP'),
             gzf_email_addr(fh.pidm, 'WORK'),
             gzf_email_addr(fh.pidm, 'SBCC'),
             gzf_email_addr(fh.pidm, 'PERS'))       email_address,
    gzf_get_id(fh.pidm, 'SSNFULL')                  tax_id,
    ''                                              buyer_entity_name,
    ''                                              vendor
FROM
         fvq_fabchks_paymnt_transaction
    JOIN fvq_fabinvh_fabinck_pt fh ON fabchks_check_num = fabinck_check_num
    LEFT JOIN fvq_vendor_info        vi ON fh.pidm = vi.pidm
    LEFT JOIN stvstat ON address_cntry_region_title = stvstat_desc
    LEFT JOIN fvq_discount_terms ON vi.disc_code = ftvdisc_code
WHERE
    fabchks_check_date BETWEEN TO_DATE('01-JAN-23') AND TO_DATE('31-DEC-23')
    AND fabchks_cancel_ind IS NULL
GROUP BY
    gzf_get_id(fh.pidm),
    coalesce(gzf_format_name(fh.pidm, 'FL'),
             initcap(fabinvh_one_time_vend_name)),
    initcap(address_line1),
    initcap(address_line2),
    initcap(address_cntry_locality),
    address_cntry_postal_code,
    stvstat_code,
    coalesce(decode(address_country, '01', 'US', address_country),
             'US'),
    coalesce(ftvdisc_desc, 'Net 30 days'),
    contact,
    phone_area
    || ' '
    || phone_number
    || nvl2(phone_ext, ' Ext: ' || phone_ext, NULL),
    coalesce(gzf_email_addr(fh.pidm, 'VNDP'),
             gzf_email_addr(fh.pidm, 'WORK'),
             gzf_email_addr(fh.pidm, 'SBCC'),
             gzf_email_addr(fh.pidm, 'PERS')),
    gzf_get_id(fh.pidm, 'SSNFULL')
ORDER BY
    1 DESC;



--------------------
OLD
-------------------
SELECT
    
    gzf_get_id(fabinvh_vend_pidm) --FABINVH_ONE_TIME_VEND_NAME
                                     vendor_id,
    ''                                                              remi_id,
    coalesce(gzf_format_name(fabinvh_vend_pidm, 'FL'),initcap(FABINVH_ONE_TIME_VEND_NAME))                        merchant_name,
    spraddr_street_line1                                            address,
    spraddr_street_line2                                            address_2nd,
    spraddr_city                                                    city,
    spraddr_zip                                                     postal_code,
    spraddr_stat_code                                               state_code,
    decode(spraddr_natn_code, '01','US',spraddr_natn_code,spraddr_natn_code,'US')                country,
    SUM(fabchks_check_amt)                                          total_spend,
    'USD'                                                           payment_currency,
    LISTAGG(DISTINCT decode(instr(fabchks_check_num, '!', 1, 1),
                            1,
                            'ACH',
                            'Check'),
                     '; ') WITHIN GROUP(
    ORDER BY
        gzf_get_id(fabinvh_vend_pidm)
    )                                                               payment_type,
    SUM(fabchks_check_amt)                                          total_currency,
    COUNT(fabchks_check_num)                                        number_of_checks,
    nvl2(ftvvend_disc_code, 'Net ' || ftvvend_disc_code, NULL)      payment_terms,
    MAX(fabchks_check_date)                                         last_date_paid,
    ftvvend_contact                                                 contact_name,
    ftvvend.ftvvend_phone_area
    || ' '
    || ftvvend.ftvvend_phone_number
    || nvl2(ftvvend_phone_ext, ' Ext: ' || ftvvend_phone_ext, NULL) phone,
    coalesce(gzf_email_addr(fabinvh_vend_pidm, 'VNDP'),
             gzf_email_addr(fabinvh_vend_pidm, 'WORK'),
             gzf_email_addr(fabinvh_vend_pidm, 'SBCC'),
             gzf_email_addr(fabinvh_vend_pidm, 'PERS'))             email_address,
    gzf_get_id(fabinvh_vend_pidm, 'SSNFULL')                        tax_id,
    ''                                                              buyer_entity_name,
    ''                                                              vendor
FROM
         fabchks
    JOIN fabinck ON fabchks_check_num = fabinck_check_num
--    JOIN FVQ_FABINVH_FABINCK_PT on fabinck
    JOIN fabinvh ON fabinck_invh_code = fabinvh_code
    LEFT JOIN spraddr ON fabinvh_vend_pidm = fabinvh_vend_pidm
                         AND spraddr.rowid = f_get_address_rowid(fabinvh_vend_pidm, 'ALUMADDR', 'A', sysdate, 1,
                                                                 'F', NULL)
    LEFT JOIN ftvvend ON fabinvh_vend_pidm = ftvvend_pidm
    LEFT JOIN favvend ON fabinvh_vend_pidm = favvend_pidm
WHERE
    fabchks_check_date BETWEEN TO_DATE('01-JAN-23') AND TO_DATE('31-DEC-24')
    AND fabchks_cancel_ind IS NULL
GROUP BY
    gzf_get_id(fabinvh_vend_pidm),
    nvl2(ftvvend_disc_code, 'Net ' || ftvvend_disc_code, NULL),
    coalesce(gzf_format_name(fabinvh_vend_pidm, 'FL'),initcap(FABINVH_ONE_TIME_VEND_NAME)),
    ftvvend_contact,
    spraddr_street_line1,
    ftvvend.ftvvend_phone_area
    || ' '
    || ftvvend.ftvvend_phone_number
    || nvl2(ftvvend_phone_ext, ' Ext: ' || ftvvend_phone_ext, NULL),
    ftvvend_contact,
    spraddr_street_line2,
    spraddr_city,
    ftvvend_disc_code,
    spraddr_zip,
    decode(spraddr_natn_code, '01','US',spraddr_natn_code,spraddr_natn_code,'US'),
    spraddr_stat_code,
    gzf_get_id(fabinvh_vend_pidm, 'SSNFULL'),
    coalesce(gzf_email_addr(fabinvh_vend_pidm, 'VNDP'),
             gzf_email_addr(fabinvh_vend_pidm, 'WORK'),
             gzf_email_addr(fabinvh_vend_pidm, 'SBCC'),
             gzf_email_addr(fabinvh_vend_pidm, 'PERS'))
ORDER BY
    1 DESC
    ;

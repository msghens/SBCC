CREATE OR REPLACE PACKAGE sbcc.szk_ag_grant AS
/**************************************************************
<sbcc-metadata>
<purpose>Add duel enroment students to a-g grant contract</purpose>  
<description></description>
<author>msghens</author>
<audit></audit>
<documentation></documentation>
<external-use></external-use>
</sbcc-metadata>       
**************************************************************/
    FUNCTION f_get_contract_num RETURN tbbcont.tbbcont_contract_number%TYPE;
    FUNCTION f_get_contract_pidm RETURN tbbcont.tbbcont_contract_number%TYPE;
    PROCEDURE p_add_contract;
    PROCEDURE p_remove_contract;
    PROCEDURE p_main;

END szk_ag_grant;
/
GRANT EXECUTE ON sbcc.szk_ag_grant TO sbcc_developer;
GRANT EXECUTE ON sbcc.szk_ag_grant TO sbcc_ise;
/

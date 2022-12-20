CREATE OR REPLACE PACKAGE BODY sbcc.szk_ag_grant AS

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

-- Initialization Data


/*
Global Contract and pidm
Knumber K01561305
pidm for contract Knum: 1561352
*/

    l_contract_num   CONSTANT tbbcont.tbbcont_contract_number%TYPE := '20000000';
    l_contract_pidm  CONSTANT tbbcont.tbbcont_pidm%TYPE := 1561352;
    l_origin         CONSTANT tbbcstu.tbbcstu_data_origin%TYPE := 'A-G Automation';
    
/* highshools that this grant applys to
--San Marcos HS- 423523
--Santa Barbara HS- 423572
--Dos Pueblos HS- 423172
--La Cuesta HS- 423269
--Alta Vista(Middle College) - 69286
*/
    TYPE highschool IS
        TABLE OF sovsbgv.sovsbgv_code%TYPE;
    highschools      highschool := highschool('423523', '423572', '423172', '423269', '69286');


-- End Initialization Data

    FUNCTION f_get_contract_num RETURN tbbcont.tbbcont_contract_number%TYPE IS
    BEGIN
        RETURN l_contract_num;
    END f_get_contract_num;

    FUNCTION f_get_contract_pidm RETURN tbbcont.tbbcont_contract_number%TYPE IS
    BEGIN
        RETURN l_contract_pidm;
    END f_get_contract_pidm;

    PROCEDURE p_add_contract AS
        v_out         VARCHAR2(18);
        c_cur         SYS_REFCURSOR;
        contract_rec  tb_contract_auth.contract_auth_rec;
    BEGIN
           
    --only run on terms where students are allowed to register
        FOR i IN (
            SELECT
                stvterm_code
            FROM
                svq_term_all
            WHERE
                stvterm_reg_allowed = 'Y'
        ) LOOP
    --go to next term if contract is not defined
            CONTINUE WHEN tb_contract_auth.f_contract_defined(p_contract_pidm => l_contract_pidm, p_term_code => i.stvterm_code, p_contract_number =>
            l_contract_num) <> 'Y';

            --dbms_output.put_line(i.stvterm_code);
            FOR student IN (
                SELECT
                    sgbstdn_pidm
                FROM
                    sgbstdn
                WHERE
                        sgbstdn_styp_code = 'Y'
                    AND sgbstdn_term_code_eff = i.stvterm_code
            ) LOOP
                CONTINUE WHEN f_get_hsch_code(student.sgbstdn_pidm) NOT MEMBER OF highschools;
            --does a student have a contract? create a contract
            --If student has a contract, is it marked deleted? If so update record
            
--                dbms_output.put_line('Added ' || student.sgbstdn_pidm || ' to contract');
                IF ( tb_contract_auth.f_student_assigned(p_contract_pidm => l_contract_pidm, p_term_code => i.stvterm_code, p_contract_number =>
                l_contract_num, p_stu_pidm => student.sgbstdn_pidm) = 'Y' ) THEN
                    c_cur := tb_contract_auth.f_query_one(p_stu_pidm => student.sgbstdn_pidm, p_contract_pidm => l_contract_pidm,
                    p_term_code => i.stvterm_code, p_contract_number => l_contract_num);

                    FETCH c_cur INTO contract_rec;
                    IF contract_rec.r_del_ind = 'D' THEN
                        tb_contract_auth.p_update(p_stu_pidm => student.sgbstdn_pidm, p_contract_pidm => l_contract_pidm, p_term_code =>
                        i.stvterm_code, p_contract_number => l_contract_num, p_del_ind => NULL);

                        COMMIT;
                    END IF;

                    CLOSE c_cur;
                ELSE
                    tb_contract_auth.p_create(p_stu_pidm => student.sgbstdn_pidm, p_contract_priority => tb_contract_auth.f_max_priority(
                    student.sgbstdn_pidm, i.stvterm_code) + 1, p_contract_pidm => l_contract_pidm, p_contract_number => l_contract_num,
                    p_term_code => i.stvterm_code, p_auth_ind => 'Y',
                                              p_student_cont_roll_ind => 'N', --tbbcstu.tbbcstu_student_cont_roll_ind%TYPE,
                                               p_data_origin => l_origin, p_rowid_out => v_out);

                    COMMIT;
                END IF;

            END LOOP;

        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE;
    END p_add_contract;
    
    --Change in status - no longer in contract. set delete flag

    PROCEDURE p_remove_contract AS

        v_out         VARCHAR2(18);
        c_cur         SYS_REFCURSOR;
        s_cur         SYS_REFCURSOR;
        contract_rec  tb_contract_auth.contract_auth_rec;
        student_rec   sb_learner.learner_rec;
    BEGIN
        FOR i IN (
            SELECT
                stvterm_code
            FROM
                svq_term_all
            WHERE
                stvterm_reg_allowed = 'Y'
        ) LOOP
            CONTINUE WHEN tb_contract_auth.f_contract_defined(p_contract_pidm => l_contract_pidm, p_term_code => i.stvterm_code, p_contract_number =>
            l_contract_num) <> 'Y';

            c_cur := tb_contract_auth.f_query_all_by_cont(p_contract_pidm => l_contract_pidm, p_term_code => i.stvterm_code, p_contract_number =>
            l_contract_num);

            LOOP
                FETCH c_cur INTO contract_rec;
                EXIT WHEN c_cur%notfound;
                --already deleted
                CONTINUE WHEN contract_rec.r_del_ind = 'D';                
                --check if contract user still exitis? dup pidm?
                --if sb_learner.f_exists(    p_pidm => contract_rec.r_pidm,p_term_code_eff => i.stvterm_code) = 'Y' then
                s_cur := sb_learner.f_query_one(p_pidm => contract_rec.r_stu_pidm, p_term_code_eff => i.stvterm_code);

                FETCH s_cur INTO student_rec;
                CLOSE s_cur;
                CONTINUE WHEN
                    student_rec.r_styp_code = 'Y' AND f_get_hsch_code(student_rec.r_pidm) MEMBER OF highschools;
                -- set delete indicator
                tb_contract_auth.p_update(p_stu_pidm => student_rec.r_pidm, p_contract_pidm => l_contract_pidm, p_term_code => i.
                stvterm_code, p_contract_number => l_contract_num, p_del_ind => 'D');

            END LOOP;

            CLOSE c_cur;
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE;
    END p_remove_contract;

    PROCEDURE p_main AS
    BEGIN
        p_add_contract;
        p_remove_contract;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE;
    END p_main;

END szk_ag_grant;

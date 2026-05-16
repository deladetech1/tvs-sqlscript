-- =====================================================
-- VIEW FOR BACKWARD COMPATIBILITY
-- =====================================================
DROP VIEW IF EXISTS loandrift.ld_loan_details_view;

CREATE VIEW loandrift.ld_loan_details_view AS
SELECT
    ld.id, ld.client_id, ld.tenant_id, ld.org_id, ld.bus_id, ld.loc_id,
    ld.loan_type, ld.sector_id, ld.interest_type_id, ld.payment_type, ld.grace_period,
    ld.registration_id, ld.status, ld.is_ready_for_approval, ld.requested_amount,
    ld.currency_id, ld.description, ld.registration_datetime, ld.delete_status, ld.is_active,
    ld.cdate, ld.ctime, ld.cdatetime, ld.created_by, ld.updated_by, ld.deleted_by,

    lc.interest_rate, lc.loan_periods, lc.interest_period, lc.repayment_weeks,
    lc.first_payment_date, lc.expected_interest_rate, lc.loan_amount, lc.loan_repayment_amount,
    lc.currency_id AS loan_calculations_currency_id,

    lch.processing_fees, lch.processing_fees_percentage, lch.insurance, lch.insurance_percentage,
    lch.other_charges, lch.other_charges_percentage, lch.bank_cheque_reference,
    lch.currency_id AS loan_charges_currency_id,

    lp.loan_purpose, lp.number_of_months,

    cfi.currently_working_with, cfi.saving_bank_with, cfi.saving_amount,
    cfi.provident_fund_with AS provident_found_with,
    cfi.provident_fund_amount AS provident_found_amount,
    cfi.life_insurance_provider, cfi.life_insurance_amount,
    cfi.salary_in_bank_with, cfi.salary_account_number, cfi.salary_amount,
    cfi.asset_name AS assert, cfi.asset_value AS assert_value,
    cfi.property_name AS property, cfi.property_value,
    cfi.borrower_monthly_salary, cfi.borrower_other_income, cfi.borrower_monthly_expenses,
    cfi.previous_loan_amount, cfi.previous_loan_amount_2,
    cfi.purpose_installment_payment, cfi.interest_amount, cfi.principal_loan_amount,
    cfi.currency_id AS client_financial_currency_id,

    la.approved_by, la.approved_amount, la.approval_date, la.approval_time, la.approved_message,

    ldis.mode, ldis.reference, ldis.disbursed_by, ldis.disbursement_date, ldis.disbursement_time
FROM loandrift.ld_loan_details ld
LEFT JOIN loandrift.ld_loan_calculations lc
    ON ld.id = lc.loan_id AND ld.tenant_id = lc.tenant_id
    AND ld.org_id = lc.org_id AND ld.bus_id = lc.bus_id AND ld.loc_id = lc.loc_id
LEFT JOIN loandrift.ld_loan_charges lch
    ON ld.id = lch.loan_id AND ld.tenant_id = lch.tenant_id
    AND ld.org_id = lch.org_id AND ld.bus_id = lch.bus_id AND ld.loc_id = lch.loc_id
LEFT JOIN loandrift.ld_loan_purpose lp
    ON ld.id = lp.loan_id AND ld.tenant_id = lp.tenant_id
    AND ld.org_id = lp.org_id AND ld.bus_id = lp.bus_id AND ld.loc_id = lp.loc_id
LEFT JOIN loandrift.ld_client_financial_info cfi
    ON ld.id = cfi.loan_id AND ld.tenant_id = cfi.tenant_id
    AND ld.org_id = cfi.org_id AND ld.bus_id = cfi.bus_id AND ld.loc_id = cfi.loc_id
LEFT JOIN loandrift.ld_loan_approvals la
    ON ld.id = la.loan_id AND ld.tenant_id = la.tenant_id
    AND ld.org_id = la.org_id AND ld.bus_id = la.bus_id AND ld.loc_id = la.loc_id
LEFT JOIN loandrift.ld_loan_disbursements ldis
    ON ld.id = ldis.loan_id AND ld.tenant_id = ldis.tenant_id
    AND ld.org_id = ldis.org_id AND ld.bus_id = ldis.bus_id AND ld.loc_id = ldis.loc_id;

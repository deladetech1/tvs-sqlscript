-- =====================================================================================
-- The last of them: Admin stops holding rows.
--
-- Admin held 510 of the 513 permissions. The three it did not hold are exactly the log
-- writes taken away by 20260928-10, and the role's own description said it could do
-- anything "except log modification" -- so the rows and the sentence already agreed, and
-- the rule now says the same thing once (tvs-package 1.0.46, Trovesuite.Package 1.0.3,
-- all four apps deployed).
--
-- Admin is NOT Owner and is deliberately a separate rule. An owner may delete an audit
-- trail; an admin may not. Collapsing them would hand that back silently, which is the one
-- outcome none of this work should produce.
--
-- With this, every role that is allowed by being the role holds nothing for it:
--
--   Owner                 0 rows   anything, anywhere
--   Admin                 0 rows   anything, anywhere, except writes to logs
--   Core Platform Admin   0 rows   Core Platform only, except writes to logs
--   Mystoreguard Admin   11 rows   MyStoreGuard, plus those Core Platform reads
--   Loandrift Admin      16 rows   LoanDrift, plus those Core Platform reads
--   ZelosHR Admin         6 rows   ZelosHR, plus those Core Platform reads
--
-- The rows that remain are Core Platform grants the rules do not cover, which is why they
-- are still rows.
--
-- Safe to rerun.
-- =====================================================================================

DELETE FROM core_platform.cp_role_permissions
 WHERE role_id = 'role-admin';

# Client and loan schema check — 12 September 2026

Checked the local `core-platform-dev` database against the current LoanDrift frontend/backend `dev` worktrees and the SQL repository worktree (now `dev`, tracking `origin/dev`). No remote database was changed.

## Schema coverage

- Client name parts and photo: `first_name`, `middle_names`, `surname`, `profile_photo_path`.
- Multiple contacts: `ld_clients.contacts` and `ld_guarantors.contacts`.
- Multiple IDs: `ld_client_identifications` (including `sort_order`) and `ld_guarantor_identifications`.
- Loan penalty configuration: loan `penalty_mode`, `penalty_enabled`, `penalty_terms`, `penalty_settings_version_id`, `penalty_percentage`; loan type `penalty_mode` and `penalty_percentage`.
- Loan details view includes repayment schedule, calculated amounts and penalty fields.

The EF model matches its migration snapshot (`has-pending-model-changes` passed). The local database already contained these fields. Applied the idempotent `20260912170018_AddGuarantorContacts` migration to reconcile its missing migration-history entry.

Existing client migrations: `AddClientProfileForm`, `AddClientIdentificationOrder`, `AddClientContacts`. Shared SQL counterparts are in `migrations/shared/20260912-01` through `20260912-04`.

## API contract correction on dev

Client statistics are derived from existing client and loan rows; they need no statistics table or new columns. Restored all eight UI metrics in the backend response, counting distinct clients, excluding deleted clients/loans and scoping joins to tenant, organisation, business and location. Completed metrics and the completed-loans list recognise both `CLOSED` and `COMPLETED`.

Regression check: `tvs-loandrift-bk/tests/check_dev_client_loan_stats.py`. Uses the local database and rollback-only temporary fixtures to cover duplicate loans, deleted clients/loans, empty branches, branch isolation and monthly counts.

## Branch/deployment note

The profile/contact entity changes, migration snapshot and migration files were already uncommitted in the SQL worktree. Preserve and commit them together on the intended integration branch before deploying or checking out elsewhere. At the user’s request, the SQL repository was switched to `dev`, tracking `origin/dev`; all 18 modified/untracked files were verified unchanged after the switch. Nothing was committed or pushed.

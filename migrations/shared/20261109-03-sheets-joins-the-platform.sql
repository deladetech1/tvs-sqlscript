-- SUPERSEDED: Office R1 (2026-11-10). This file does nothing (its one statement is SELECT 1, so the runner never sends an empty command).
--
-- In R0 this file registered Sheets joined the platform (app-sheets). The owner then made Docs, Sheets and Slides
-- ONE app, Office (app-office): 20261110-01-office-joins-the-platform.sql and
-- 20261110-02-office-library.sql replace 20261109-01..06, and
-- 20261110-03-office-retires-docs-sheets-slides.sql removes what R0 left on a database that ran it.
--
-- Why the body is gone and the file is not: migrations re-run on every deploy, in filename order,
-- before the 20261110 files. Re-creating the R0 apps here, only for 20261110-03 to remove them
-- again, would churn every deploy, and would fail anyway once the seed stopped creating their
-- cp_apps rows. R0 reached dev only (master, which is prod, never ran it), so nothing anywhere
-- depends on these statements running again. The file name stays so the history reads in order;
-- the original body is in git (commits 539b8c8 and 4b8c8e7).
--
-- Design: tvs-shared-apps-bk docs/office-apps/contracts/R1-suite.md §3.

SELECT 1;

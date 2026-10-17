using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.Accounting.Migrations
{
    /// <inheritdoc />
    public partial class RetireLegacyPermissionIds : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Moved to the end of Sql/Seeds/04_others.sql. EF migrations run before the seeds, so on a database
            // that skipped the deploy that seeded the replacing ids this could not carry any grant and its guard
            // would stop every deploy. saas-dev ran the original body on 2026-10-17 (tvs-sqlscript 7946a50); the
            // seed block finds nothing left to do there.
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Nothing to undo.
        }
    }
}

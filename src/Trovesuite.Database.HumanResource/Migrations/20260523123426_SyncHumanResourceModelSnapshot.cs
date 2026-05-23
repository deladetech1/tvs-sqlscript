using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    /// <remarks>
    /// Snapshot-only sync after parallel merge (EmployeeOnboarding + ZelosHr). DDL is already
    /// applied by earlier migrations; this entry aligns HumanResourceDbContextModelSnapshot with the model.
    /// </remarks>
    public partial class SyncHumanResourceModelSnapshot : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
        }
    }
}

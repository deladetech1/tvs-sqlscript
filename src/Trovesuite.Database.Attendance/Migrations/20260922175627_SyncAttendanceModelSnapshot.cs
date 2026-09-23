using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.Attendance.Migrations;

/// <summary>
/// Snapshot-only sync. Prior Attendance migrations were hand-written with stub
/// Designers / an empty <c>AttendanceDbContextModelSnapshot</c>, so EF Core
/// treated the full model as pending and failed deploy with
/// <c>PendingModelChangesWarning</c>. Schema DDL already lives in
/// <c>Initial</c>, <c>AddPortalTables</c>, and <c>AddZktecoAdmsDeviceFields</c>
/// — this migration only records the current model in the snapshot.
/// </summary>
public partial class SyncAttendanceModelSnapshot : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        // Intentionally empty — model snapshot catch-up only.
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        // Intentionally empty — model snapshot catch-up only.
    }
}

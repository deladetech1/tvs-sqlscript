using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.Attendance.Migrations;

/// <summary>
/// ZKTeco ADMS (cloud push): enable flag, last-seen, unique serial, punch dedupe.
/// </summary>
public partial class AddZktecoAdmsDeviceFields : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<bool>(
            name: "is_enabled",
            schema: "attendance",
            table: "att_devices",
            type: "boolean",
            nullable: false,
            defaultValue: true);

        migrationBuilder.AddColumn<DateTimeOffset>(
            name: "last_seen_at",
            schema: "attendance",
            table: "att_devices",
            type: "timestamp with time zone",
            nullable: true);

        migrationBuilder.CreateIndex(
            name: "ix_att_devices_serial",
            schema: "attendance",
            table: "att_devices",
            column: "serial",
            unique: true,
            filter: "serial IS NOT NULL AND serial <> ''");

        migrationBuilder.CreateIndex(
            name: "ix_att_punches_device_employee_punched_at",
            schema: "attendance",
            table: "att_punches",
            columns: new[] { "device_id", "employee_id", "punched_at" },
            unique: true,
            filter: "device_id IS NOT NULL AND is_superseded = false");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropIndex(
            name: "ix_att_punches_device_employee_punched_at",
            schema: "attendance",
            table: "att_punches");

        migrationBuilder.DropIndex(
            name: "ix_att_devices_serial",
            schema: "attendance",
            table: "att_devices");

        migrationBuilder.DropColumn(
            name: "last_seen_at",
            schema: "attendance",
            table: "att_devices");

        migrationBuilder.DropColumn(
            name: "is_enabled",
            schema: "attendance",
            table: "att_devices");
    }
}

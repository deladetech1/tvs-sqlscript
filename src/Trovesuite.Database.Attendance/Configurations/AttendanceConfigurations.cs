using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.Attendance.Entities;

namespace Trovesuite.Database.Attendance.Configurations;

internal static class AttendanceTableExtensions
{
    internal static EntityTypeBuilder<T> ToAttendanceTable<T>(this EntityTypeBuilder<T> b, string tableName)
        where T : class => b.ToTable(tableName, AttendanceDbContext.SchemaName);
}

public sealed class AttAttendanceRecordConfiguration : IEntityTypeConfiguration<AttAttendanceRecord>
{
    public void Configure(EntityTypeBuilder<AttAttendanceRecord> b)
    {
        b.ToAttendanceTable("att_attendance_records");
        b.HasKey(x => x.Id);
        b.Property(x => x.HoursWorked).HasPrecision(5, 2);
        b.Property(x => x.CaptureSource).HasDefaultValue("web");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.AttendanceDate });
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.EmployeeId, x.AttendanceDate }).IsUnique();
    }
}

public sealed class AttEmployeeConfiguration : IEntityTypeConfiguration<AttEmployee>
{
    public void Configure(EntityTypeBuilder<AttEmployee> b)
    {
        b.ToAttendanceTable("att_employees");
        b.HasKey(x => x.Id);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.EmployeeCode }).IsUnique();
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.ReportsToEmployeeId });
    }
}

public sealed class AttPunchConfiguration : IEntityTypeConfiguration<AttPunch>
{
    public void Configure(EntityTypeBuilder<AttPunch> b)
    {
        b.ToAttendanceTable("att_punches");
        b.HasKey(x => x.Id);
        b.Property(x => x.Source).HasDefaultValue("web");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.EmployeeId, x.PunchedAt });
        b.HasIndex(x => x.AttendanceId);
        b.HasIndex(x => new { x.DeviceId, x.EmployeeId, x.PunchedAt })
            .IsUnique()
            .HasFilter("device_id IS NOT NULL AND is_superseded = false");
    }
}

public sealed class AttAdjustmentConfiguration : IEntityTypeConfiguration<AttAdjustment>
{
    public void Configure(EntityTypeBuilder<AttAdjustment> b)
    {
        b.ToAttendanceTable("att_adjustments");
        b.HasKey(x => x.Id);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.EmployeeId, x.AttendanceDate });
    }
}

public sealed class AttDeviceConfiguration : IEntityTypeConfiguration<AttDevice>
{
    public void Configure(EntityTypeBuilder<AttDevice> b)
    {
        b.ToAttendanceTable("att_devices");
        b.HasKey(x => x.Id);
        b.Property(x => x.IsEnabled).HasDefaultValue(true);
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.Name });
        // One physical device SN maps to one tenant/org registration.
        b.HasIndex(x => x.Serial)
            .IsUnique()
            .HasFilter("serial IS NOT NULL AND serial <> ''");
    }
}

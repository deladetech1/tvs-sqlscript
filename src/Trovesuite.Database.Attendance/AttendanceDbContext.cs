using Microsoft.EntityFrameworkCore;
using Trovesuite.Database.Attendance.Entities;

namespace Trovesuite.Database.Attendance;

public class AttendanceDbContext : DbContext
{
    public const string SchemaName = "attendance";

    public AttendanceDbContext(DbContextOptions<AttendanceDbContext> options) : base(options) { }

    public DbSet<AttAttendanceRecord> AttendanceRecords => Set<AttAttendanceRecord>();
    public DbSet<AttEmployee> Employees => Set<AttEmployee>();
    public DbSet<AttPunch> Punches => Set<AttPunch>();
    public DbSet<AttAdjustment> Adjustments => Set<AttAdjustment>();
    public DbSet<AttDevice> Devices => Set<AttDevice>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasDefaultSchema(SchemaName);
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AttendanceDbContext).Assembly);
        base.OnModelCreating(modelBuilder);
    }
}

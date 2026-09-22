using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace Trovesuite.Database.Attendance;

/// <summary>
/// Used by the EF Core tooling (<c>dotnet ef migrations add</c>, <c>dotnet ef migrations script</c>)
/// at design time. The connection string here is a placeholder — <c>migrations add</c> only
/// builds the model, it never opens a connection.
/// </summary>
public sealed class AttendanceDbContextFactory : IDesignTimeDbContextFactory<AttendanceDbContext>
{
    public AttendanceDbContext CreateDbContext(string[] args)
    {
        var cs = Environment.GetEnvironmentVariable("TVS_DESIGN_CONNECTION")
                 ?? "Host=localhost;Port=5432;Username=postgres;Password=postgres;Database=trovesuite_design";

        var options = new DbContextOptionsBuilder<AttendanceDbContext>()
            .UseNpgsql(cs, npg =>
                npg.MigrationsHistoryTable("__EFMigrationsHistory", AttendanceDbContext.SchemaName))
            .UseSnakeCaseNamingConvention()
            .Options;

        return new AttendanceDbContext(options);
    }
}

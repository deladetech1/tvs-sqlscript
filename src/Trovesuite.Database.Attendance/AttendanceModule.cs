using Microsoft.EntityFrameworkCore;
using Trovesuite.Database.Common.Abstractions;

namespace Trovesuite.Database.Attendance;

public sealed class AttendanceModule : IModule
{
    public int Order => 5;
    public string ModuleKey => "attendance";
    public string SchemaName => AttendanceDbContext.SchemaName;

    public DbContext CreateContext(string connectionString)
    {
        var options = new DbContextOptionsBuilder<AttendanceDbContext>()
            .UseNpgsql(connectionString, npg =>
                npg.MigrationsHistoryTable("__EFMigrationsHistory", AttendanceDbContext.SchemaName))
            .UseSnakeCaseNamingConvention()
            .Options;
        return new AttendanceDbContext(options);
    }

    public async Task SeedAsync(DbContext context, CancellationToken ct = default)
    {
        var assembly = typeof(AttendanceModule).Assembly;
        foreach (var (_, body) in EmbeddedSql.LoadAllOrdered(assembly, "Seeds"))
            await context.Database.ExecuteSqlRawAsync(body, ct);
    }
}

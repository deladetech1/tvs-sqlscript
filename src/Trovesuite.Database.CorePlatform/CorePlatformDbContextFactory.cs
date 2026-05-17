using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace Trovesuite.Database.CorePlatform;

/// <summary>
/// Used by the EF Core tooling (`dotnet ef migrations add`, `dotnet ef migrations script`)
/// to construct a DbContext without going through the Runner CLI. The connection
/// string here is a placeholder — `migrations add` only builds the model, it never
/// opens a connection.
/// </summary>
public sealed class CorePlatformDbContextFactory : IDesignTimeDbContextFactory<CorePlatformDbContext>
{
    public CorePlatformDbContext CreateDbContext(string[] args)
    {
        var cs = Environment.GetEnvironmentVariable("TVS_DESIGN_CONNECTION")
                 ?? "Host=localhost;Port=5432;Username=postgres;Password=postgres;Database=trovesuite_design";

        var options = new DbContextOptionsBuilder<CorePlatformDbContext>()
            .UseNpgsql(cs, npg =>
                npg.MigrationsHistoryTable("__EFMigrationsHistory", CorePlatformDbContext.SchemaName))
            .UseSnakeCaseNamingConvention()
            .Options;

        return new CorePlatformDbContext(options);
    }
}

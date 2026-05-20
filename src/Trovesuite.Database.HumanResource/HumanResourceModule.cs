using Microsoft.EntityFrameworkCore;
using Trovesuite.Database.Common.Abstractions;

namespace Trovesuite.Database.HumanResource;

public sealed class HumanResourceModule : IModule
{
    public int Order => 4;
    public string ModuleKey => "human_resource";
    public string SchemaName => HumanResourceDbContext.SchemaName;

    public DbContext CreateContext(string connectionString)
    {
        var options = new DbContextOptionsBuilder<HumanResourceDbContext>()
            // See note in CorePlatformModule — Npgsql puts history in `public` by
            // default; pin it to the module's schema so rollbacks are complete.
            .UseNpgsql(connectionString, npg =>
                npg.MigrationsHistoryTable("__EFMigrationsHistory", HumanResourceDbContext.SchemaName))
            .UseSnakeCaseNamingConvention()
            .Options;
        return new HumanResourceDbContext(options);
    }

    public async Task SeedAsync(DbContext context, CancellationToken ct = default)
    {
        var assembly = typeof(HumanResourceModule).Assembly;
        var seedDemo = IsTruthy(Environment.GetEnvironmentVariable("TVS_SEED_ZELOSHR_DEMO"));

        foreach (var (name, body) in EmbeddedSql.LoadAllOrdered(assembly, "Seeds"))
        {
            if (name.Contains("05_zeloshr_demo", StringComparison.OrdinalIgnoreCase) && !seedDemo)
                continue;

            await context.Database.ExecuteSqlRawAsync(body, ct);
        }
    }

    private static bool IsTruthy(string? value) =>
        string.Equals(value, "1", StringComparison.Ordinal)
        || string.Equals(value, "true", StringComparison.OrdinalIgnoreCase);
}

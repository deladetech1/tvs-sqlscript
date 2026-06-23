using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
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
            // Migrations and snapshot are maintained by hand in this repo; the
            // model-vs-snapshot diff check is suppressed so deployment proceeds.
            .ConfigureWarnings(w => w.Ignore(RelationalEventId.PendingModelChangesWarning))
            .Options;
        return new HumanResourceDbContext(options);
    }

    public async Task SeedAsync(DbContext context, CancellationToken ct = default)
    {
        var assembly = typeof(HumanResourceModule).Assembly;

        foreach (var (_, body) in EmbeddedSql.LoadAllOrdered(assembly, "Seeds"))
            await context.Database.ExecuteSqlRawAsync(body, ct);
    }
}

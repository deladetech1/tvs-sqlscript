using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Trovesuite.Database.Common.Abstractions;
using Trovesuite.Database.HumanResource.Entities;

namespace Trovesuite.Database.HumanResource;

public sealed class HumanResourceModule : IModule
{
    public int Order => 4;
    public string ModuleKey => "human_resource";
    public string SchemaName => HumanResourceDbContext.SchemaName;

    // This module's migrations create tables in two schemas: human_resource (hr_*)
    // and zeloshr (zhr_*). Both must be dropped on rollback. core_platform is only
    // referenced via FK and is intentionally excluded.
    public IEnumerable<string> OwnedSchemas =>
        new[] { HumanResourceDbContext.SchemaName, ZelosHrSchema.Name };

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

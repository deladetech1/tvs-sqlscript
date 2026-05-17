using Microsoft.EntityFrameworkCore;
using Trovesuite.Database.Common.Abstractions;

namespace Trovesuite.Database.CorePlatform;

public sealed class CorePlatformModule : IModule
{
    public int Order => 1;
    public string ModuleKey => "core_platform";
    public string SchemaName => CorePlatformDbContext.SchemaName;

    public DbContext CreateContext(string connectionString)
    {
        var options = new DbContextOptionsBuilder<CorePlatformDbContext>()
            // Pin __EFMigrationsHistory inside the module's own schema. Npgsql's
            // provider defaults to `public` even when HasDefaultSchema(...) is set,
            // which makes per-module rollbacks (DROP SCHEMA CASCADE) leak history.
            .UseNpgsql(connectionString, npg =>
                npg.MigrationsHistoryTable("__EFMigrationsHistory", CorePlatformDbContext.SchemaName))
            .UseSnakeCaseNamingConvention()
            .Options;
        return new CorePlatformDbContext(options);
    }

    /// <summary>
    /// Post-migration setup. Order matches the legacy script_db_setup.sh:
    ///   1. Triggers (so seeding fires permission-assignment triggers).
    ///   2. Resource types.
    ///   3. Permissions  (triggers cascade these to Owner/Admin/etc).
    ///   4. Roles        (triggers cascade resource permissions in).
    ///   5. Others       (role-permission overrides, default groups, subscriptions, apps, tier configs, app features).
    /// </summary>
    public async Task SeedAsync(DbContext context, CancellationToken ct = default)
    {
        var assembly = typeof(CorePlatformModule).Assembly;

        // Triggers first — PL/pgSQL functions + AFTER INSERT triggers on cp_roles / cp_permissions.
        foreach (var (_, body) in EmbeddedSql.LoadAllOrdered(assembly, "Triggers"))
            await context.Database.ExecuteSqlRawAsync(body, ct);

        // Then seed data in the same order as the legacy SQL files.
        foreach (var (_, body) in EmbeddedSql.LoadAllOrdered(assembly, "Seeds"))
            await context.Database.ExecuteSqlRawAsync(body, ct);
    }
}

using Microsoft.EntityFrameworkCore;
using Trovesuite.Database.Common.Abstractions;

namespace Trovesuite.Database.MyStoreGuard;

public sealed class MyStoreGuardModule : IModule
{
    public int Order => 3;
    public string ModuleKey => "mystoreguard";
    public string SchemaName => MyStoreGuardDbContext.SchemaName;

    public DbContext CreateContext(string connectionString)
    {
        var options = new DbContextOptionsBuilder<MyStoreGuardDbContext>()
            // See note in CorePlatformModule — Npgsql puts history in `public` by
            // default; pin it to the module's schema so rollbacks are complete.
            .UseNpgsql(connectionString, npg =>
                npg.MigrationsHistoryTable("__EFMigrationsHistory", MyStoreGuardDbContext.SchemaName))
            .UseSnakeCaseNamingConvention()
            .Options;
        return new MyStoreGuardDbContext(options);
    }

    public async Task SeedAsync(DbContext context, CancellationToken ct = default)
    {
        var assembly = typeof(MyStoreGuardModule).Assembly;

        foreach (var (_, body) in EmbeddedSql.LoadAllOrdered(assembly, "Triggers"))
            await context.Database.ExecuteSqlRawAsync(body, ct);

        foreach (var (_, body) in EmbeddedSql.LoadAllOrdered(assembly, "Seeds"))
            await context.Database.ExecuteSqlRawAsync(body, ct);
    }
}

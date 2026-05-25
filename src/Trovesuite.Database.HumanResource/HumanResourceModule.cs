using Microsoft.EntityFrameworkCore;
using Trovesuite.Database.Common.Abstractions;
using Trovesuite.Database.HumanResource.Seeds;

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
        if (context is not HumanResourceDbContext hrContext)
            throw new InvalidOperationException(
                $"{nameof(HumanResourceModule)} requires a {nameof(HumanResourceDbContext)} instance.");

        await HumanResourceRbacSeeder.SeedAsync(hrContext, ct);
    }
}

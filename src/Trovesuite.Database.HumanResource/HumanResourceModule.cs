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
            .UseNpgsql(connectionString)
            .UseSnakeCaseNamingConvention()
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

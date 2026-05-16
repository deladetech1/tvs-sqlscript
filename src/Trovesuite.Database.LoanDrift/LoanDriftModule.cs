using Microsoft.EntityFrameworkCore;
using Trovesuite.Database.Common.Abstractions;

namespace Trovesuite.Database.LoanDrift;

public sealed class LoanDriftModule : IModule
{
    public int Order => 2;
    public string ModuleKey => "loandrift";
    public string SchemaName => LoanDriftDbContext.SchemaName;

    public DbContext CreateContext(string connectionString)
    {
        var options = new DbContextOptionsBuilder<LoanDriftDbContext>()
            .UseNpgsql(connectionString)
            .UseSnakeCaseNamingConvention()
            .Options;
        return new LoanDriftDbContext(options);
    }

    public async Task SeedAsync(DbContext context, CancellationToken ct = default)
    {
        var assembly = typeof(LoanDriftModule).Assembly;

        // Rebuild status CHECK and re-create the loan_details_view.
        foreach (var (_, body) in EmbeddedSql.LoadAllOrdered(assembly, "Triggers"))
        {
            await context.Database.ExecuteSqlRawAsync(body, ct);
        }

        // Seed: resource types -> permissions -> roles -> others.
        foreach (var (_, body) in EmbeddedSql.LoadAllOrdered(assembly, "Seeds"))
        {
            await context.Database.ExecuteSqlRawAsync(body, ct);
        }
    }
}

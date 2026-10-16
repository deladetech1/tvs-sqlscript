using Microsoft.EntityFrameworkCore;
using Trovesuite.Database.Common.Abstractions;

namespace Trovesuite.Database.Accounting;

public sealed class AccountingModule : IModule
{
    public int Order => 6;
    public string ModuleKey => "accounting";
    public string SchemaName => AccountingDbContext.SchemaName;

    public DbContext CreateContext(string connectionString)
    {
        var options = new DbContextOptionsBuilder<AccountingDbContext>()
            .UseNpgsql(connectionString, npg =>
                npg.MigrationsHistoryTable("__EFMigrationsHistory", AccountingDbContext.SchemaName))
            .UseSnakeCaseNamingConvention()
            .Options;
        return new AccountingDbContext(options);
    }

    public async Task SeedAsync(DbContext context, CancellationToken ct = default)
    {
        var assembly = typeof(AccountingModule).Assembly;
        foreach (var (_, body) in EmbeddedSql.LoadAllOrdered(assembly, "Seeds"))
            await context.Database.ExecuteSqlRawAsync(body, ct);
    }
}

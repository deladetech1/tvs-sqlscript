using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace Trovesuite.Database.Accounting;

/// <summary>
/// Design-time factory for <c>dotnet ef migrations add</c>. Connection is a placeholder.
/// </summary>
public sealed class AccountingDbContextFactory : IDesignTimeDbContextFactory<AccountingDbContext>
{
    public AccountingDbContext CreateDbContext(string[] args)
    {
        var cs = Environment.GetEnvironmentVariable("TVS_DESIGN_CONNECTION")
                 ?? "Host=localhost;Port=5432;Username=postgres;Password=postgres;Database=trovesuite_design";

        var options = new DbContextOptionsBuilder<AccountingDbContext>()
            .UseNpgsql(cs, npg =>
                npg.MigrationsHistoryTable("__EFMigrationsHistory", AccountingDbContext.SchemaName))
            .UseSnakeCaseNamingConvention()
            .Options;

        return new AccountingDbContext(options);
    }
}

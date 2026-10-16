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
            // The migrations here are written by hand and the model snapshot is a stub, so
            // EF always sees the model as ahead of the migrations and refuses to migrate
            // (PendingModelChangesWarning) -- which stopped every dev deploy, all modules and
            // shared SQL with it. Until the module has a generated migration and snapshot,
            // the hand-written migrations are taken as they are.
            .ConfigureWarnings(w => w.Ignore(Microsoft.EntityFrameworkCore.Diagnostics.RelationalEventId.PendingModelChangesWarning))
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

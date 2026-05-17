using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace Trovesuite.Database.HumanResource;

public sealed class HumanResourceDbContextFactory : IDesignTimeDbContextFactory<HumanResourceDbContext>
{
    public HumanResourceDbContext CreateDbContext(string[] args)
    {
        var cs = Environment.GetEnvironmentVariable("TVS_DESIGN_CONNECTION")
                 ?? "Host=localhost;Port=5432;Username=postgres;Password=postgres;Database=trovesuite_design";

        var options = new DbContextOptionsBuilder<HumanResourceDbContext>()
            .UseNpgsql(cs, npg =>
                npg.MigrationsHistoryTable("__EFMigrationsHistory", HumanResourceDbContext.SchemaName))
            .UseSnakeCaseNamingConvention()
            .Options;

        return new HumanResourceDbContext(options);
    }
}

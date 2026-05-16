using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace Trovesuite.Database.MyStoreGuard;

public sealed class MyStoreGuardDbContextFactory : IDesignTimeDbContextFactory<MyStoreGuardDbContext>
{
    public MyStoreGuardDbContext CreateDbContext(string[] args)
    {
        var cs = Environment.GetEnvironmentVariable("TVS_DESIGN_CONNECTION")
                 ?? "Host=localhost;Port=5432;Username=postgres;Password=postgres;Database=trovesuite_design";

        var options = new DbContextOptionsBuilder<MyStoreGuardDbContext>()
            .UseNpgsql(cs)
            .UseSnakeCaseNamingConvention()
            .Options;

        return new MyStoreGuardDbContext(options);
    }
}

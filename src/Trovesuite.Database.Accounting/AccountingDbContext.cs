using Microsoft.EntityFrameworkCore;
using Trovesuite.Database.Accounting.Entities;

namespace Trovesuite.Database.Accounting;

public class AccountingDbContext : DbContext
{
    public const string SchemaName = "accounting";

    public AccountingDbContext(DbContextOptions<AccountingDbContext> options) : base(options) { }

    public DbSet<AccOrgSettings> OrgSettings => Set<AccOrgSettings>();
    public DbSet<AccAccount> Accounts => Set<AccAccount>();
    public DbSet<AccFiscalPeriod> FiscalPeriods => Set<AccFiscalPeriod>();
    public DbSet<AccJournalEntry> JournalEntries => Set<AccJournalEntry>();
    public DbSet<AccJournalLine> JournalLines => Set<AccJournalLine>();
    public DbSet<AccAuditEvent> AuditEvents => Set<AccAuditEvent>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasDefaultSchema(SchemaName);
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AccountingDbContext).Assembly);
        base.OnModelCreating(modelBuilder);
    }
}

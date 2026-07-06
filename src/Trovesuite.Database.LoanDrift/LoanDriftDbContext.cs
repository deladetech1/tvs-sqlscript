using Microsoft.EntityFrameworkCore;
using Trovesuite.Database.CorePlatform;
using Trovesuite.Database.LoanDrift.Entities;

namespace Trovesuite.Database.LoanDrift;

public class LoanDriftDbContext : DbContext
{
    public const string SchemaName = "loandrift";

    public LoanDriftDbContext(DbContextOptions<LoanDriftDbContext> options) : base(options) { }

    public DbSet<Client> Clients => Set<Client>();
    public DbSet<LoanDriftActivityLog> ActivityLogs => Set<LoanDriftActivityLog>();
    public DbSet<ClientBusiness> ClientBusinesses => Set<ClientBusiness>();
    public DbSet<Sector> Sectors => Set<Sector>();
    public DbSet<LoanType> LoanTypes => Set<LoanType>();
    public DbSet<InterestType> InterestTypes => Set<InterestType>();
    public DbSet<LoanDetail> LoanDetails => Set<LoanDetail>();
    public DbSet<LoanCalculation> LoanCalculations => Set<LoanCalculation>();
    public DbSet<LoanCharge> LoanCharges => Set<LoanCharge>();
    public DbSet<LoanPurpose> LoanPurposes => Set<LoanPurpose>();
    public DbSet<ClientFinancialInfo> ClientFinancialInfos => Set<ClientFinancialInfo>();
    public DbSet<LoanApproval> LoanApprovals => Set<LoanApproval>();
    public DbSet<LoanDisbursement> LoanDisbursements => Set<LoanDisbursement>();
    public DbSet<LoanMessage> LoanMessages => Set<LoanMessage>();
    public DbSet<ClientComment> ClientComments => Set<ClientComment>();
    public DbSet<Guarantor> Guarantors => Set<Guarantor>();
    public DbSet<LoanDriftResourceDeletionChatHistory> ResourceDeletionChatHistories
        => Set<LoanDriftResourceDeletionChatHistory>();
    public DbSet<Repayment> Repayments => Set<Repayment>();
    public DbSet<ClientDocumentPath> ClientDocumentsPaths => Set<ClientDocumentPath>();

    // Savings & Investments
    public DbSet<SavingsProduct> SavingsProducts => Set<SavingsProduct>();
    public DbSet<SavingsAccount> SavingsAccounts => Set<SavingsAccount>();
    public DbSet<SavingsTransaction> SavingsTransactions => Set<SavingsTransaction>();
    public DbSet<InvestmentProduct> InvestmentProducts => Set<InvestmentProduct>();
    public DbSet<Investment> Investments => Set<Investment>();
    public DbSet<InvestmentTransaction> InvestmentTransactions => Set<InvestmentTransaction>();

    // Credit scoring
    public DbSet<CreditScoreSettings> CreditScoreSettings => Set<CreditScoreSettings>();
    public DbSet<CreditScoreSettingsHistory> CreditScoreSettingsHistories => Set<CreditScoreSettingsHistory>();
    public DbSet<CreditScore> CreditScores => Set<CreditScore>();

    // Loan penalties
    public DbSet<PenaltySettings> PenaltySettings => Set<PenaltySettings>();
    public DbSet<PenaltySettingsHistory> PenaltySettingsHistories => Set<PenaltySettingsHistory>();
    public DbSet<Penalty> Penalties => Set<Penalty>();
    public DbSet<PenaltyWaiver> PenaltyWaivers => Set<PenaltyWaiver>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasDefaultSchema(SchemaName);
        ExternalCorePlatformEntities.Register(modelBuilder);
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(LoanDriftDbContext).Assembly);
        base.OnModelCreating(modelBuilder);
    }
}

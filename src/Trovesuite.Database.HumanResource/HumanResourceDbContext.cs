using Microsoft.EntityFrameworkCore;
using Trovesuite.Database.CorePlatform;
using Trovesuite.Database.HumanResource.Entities;

namespace Trovesuite.Database.HumanResource;

public class HumanResourceDbContext : DbContext
{
    public const string SchemaName = "human_resource";

    public HumanResourceDbContext(DbContextOptions<HumanResourceDbContext> options) : base(options) { }

    public DbSet<Employee> Employees => Set<Employee>();
    public DbSet<Department> Departments => Set<Department>();
    public DbSet<PensionProvider> PensionProviders => Set<PensionProvider>();
    public DbSet<Bank> Banks => Set<Bank>();
    public DbSet<BankBranch> BankBranches => Set<BankBranch>();
    public DbSet<EmployeeStatutory> EmployeeStatutories => Set<EmployeeStatutory>();
    public DbSet<EmployeePaymentMethod> EmployeePaymentMethods => Set<EmployeePaymentMethod>();
    public DbSet<EmployeeSalary> EmployeeSalaries => Set<EmployeeSalary>();
    public DbSet<EmployeeEmergencyContact> EmployeeEmergencyContacts => Set<EmployeeEmergencyContact>();
    public DbSet<HrDocumentPath> HrDocumentPaths => Set<HrDocumentPath>();
    public DbSet<EmployeeDocument> EmployeeDocuments => Set<EmployeeDocument>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasDefaultSchema(SchemaName);
        ExternalCorePlatformEntities.Register(modelBuilder);
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(HumanResourceDbContext).Assembly);
        base.OnModelCreating(modelBuilder);
    }
}

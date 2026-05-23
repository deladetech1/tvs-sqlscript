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

    public DbSet<ZhrBranch> ZhrBranches => Set<ZhrBranch>();
    public DbSet<ZhrDepartment> ZhrDepartments => Set<ZhrDepartment>();
    public DbSet<ZhrEmployee> ZhrEmployees => Set<ZhrEmployee>();
    public DbSet<ZhrAuditLog> ZhrAuditLogs => Set<ZhrAuditLog>();
    public DbSet<ZhrLifecycleEvent> ZhrLifecycleEvents => Set<ZhrLifecycleEvent>();
    public DbSet<ZhrAttendanceRecord> ZhrAttendanceRecords => Set<ZhrAttendanceRecord>();
    public DbSet<ZhrLeaveRequest> ZhrLeaveRequests => Set<ZhrLeaveRequest>();
    public DbSet<ZhrLeaveBalance> ZhrLeaveBalances => Set<ZhrLeaveBalance>();
    public DbSet<ZhrJobPosting> ZhrJobPostings => Set<ZhrJobPosting>();
    public DbSet<ZhrOnboardingTask> ZhrOnboardingTasks => Set<ZhrOnboardingTask>();
    public DbSet<ZhrPerformanceReview> ZhrPerformanceReviews => Set<ZhrPerformanceReview>();
    public DbSet<ZhrDisciplinaryCase> ZhrDisciplinaryCases => Set<ZhrDisciplinaryCase>();
    public DbSet<ZhrEmployeeDocument> ZhrEmployeeDocuments => Set<ZhrEmployeeDocument>();
    public DbSet<ZhrEmployeeEducation> ZhrEmployeeEducations => Set<ZhrEmployeeEducation>();
    public DbSet<ZhrEmployeeCertification> ZhrEmployeeCertifications => Set<ZhrEmployeeCertification>();
    public DbSet<ZhrCustomFieldDefinition> ZhrCustomFieldDefinitions => Set<ZhrCustomFieldDefinition>();
    public DbSet<ZhrCustomFieldAuditLog> ZhrCustomFieldAuditLogs => Set<ZhrCustomFieldAuditLog>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasDefaultSchema(SchemaName);
        ExternalCorePlatformEntities.Register(modelBuilder);
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(HumanResourceDbContext).Assembly);
        base.OnModelCreating(modelBuilder);
    }
}

using Microsoft.EntityFrameworkCore;
using Trovesuite.Database.CorePlatform;
using Trovesuite.Database.HumanResource.Entities;

namespace Trovesuite.Database.HumanResource;

public class HumanResourceDbContext : DbContext
{
    // This module manages only the ZelosHR application schema (zeloshr). The legacy
    // human_resource (hr_*) schema was removed.
    public const string SchemaName = ZelosHrSchema.Name;

    public HumanResourceDbContext(DbContextOptions<HumanResourceDbContext> options) : base(options) { }

    public DbSet<ZhrBranch> ZhrBranches => Set<ZhrBranch>();
    public DbSet<ZhrDepartment> ZhrDepartments => Set<ZhrDepartment>();
    public DbSet<ZhrEmploymentType> ZhrEmploymentTypes => Set<ZhrEmploymentType>();
    public DbSet<ZhrIdCardType> ZhrIdCardTypes => Set<ZhrIdCardType>();
    public DbSet<ZhrCompanyProfile> ZhrCompanyProfiles => Set<ZhrCompanyProfile>();
    public DbSet<ZhrCompanyOffice> ZhrCompanyOffices => Set<ZhrCompanyOffice>();
    public DbSet<ZhrCompanyLocalization> ZhrCompanyLocalizations => Set<ZhrCompanyLocalization>();
    public DbSet<ZhrEmployee> ZhrEmployees => Set<ZhrEmployee>();
    public DbSet<ZhrAuditLog> ZhrAuditLogs => Set<ZhrAuditLog>();
    public DbSet<ZhrLifecycleEvent> ZhrLifecycleEvents => Set<ZhrLifecycleEvent>();
    public DbSet<ZhrAttendanceRecord> ZhrAttendanceRecords => Set<ZhrAttendanceRecord>();
    public DbSet<ZhrLeaveRequest> ZhrLeaveRequests => Set<ZhrLeaveRequest>();
    public DbSet<ZhrLeaveBalance> ZhrLeaveBalances => Set<ZhrLeaveBalance>();
    public DbSet<ZhrLeaveType> ZhrLeaveTypes => Set<ZhrLeaveType>();
    public DbSet<ZhrPublicHoliday> ZhrPublicHolidays => Set<ZhrPublicHoliday>();
    public DbSet<ZhrJobPosting> ZhrJobPostings => Set<ZhrJobPosting>();
    public DbSet<ZhrOnboardingTask> ZhrOnboardingTasks => Set<ZhrOnboardingTask>();
    public DbSet<ZhrPerformanceReview> ZhrPerformanceReviews => Set<ZhrPerformanceReview>();
    public DbSet<ZhrDisciplinaryCase> ZhrDisciplinaryCases => Set<ZhrDisciplinaryCase>();
    public DbSet<ZhrEmployeeDocument> ZhrEmployeeDocuments => Set<ZhrEmployeeDocument>();
    public DbSet<ZhrEmployeeEducation> ZhrEmployeeEducations => Set<ZhrEmployeeEducation>();
    public DbSet<ZhrEmployeeCertification> ZhrEmployeeCertifications => Set<ZhrEmployeeCertification>();
    public DbSet<ZhrEmployeeIdentification> ZhrEmployeeIdentifications => Set<ZhrEmployeeIdentification>();
    public DbSet<ZhrCustomFieldDefinition> ZhrCustomFieldDefinitions => Set<ZhrCustomFieldDefinition>();
    public DbSet<ZhrCustomFieldAuditLog> ZhrCustomFieldAuditLogs => Set<ZhrCustomFieldAuditLog>();
    public DbSet<ZhrEmployeeChangeRequest> ZhrEmployeeChangeRequests => Set<ZhrEmployeeChangeRequest>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasDefaultSchema(SchemaName);
        ExternalCorePlatformEntities.Register(modelBuilder);
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(HumanResourceDbContext).Assembly);
        base.OnModelCreating(modelBuilder);
    }
}

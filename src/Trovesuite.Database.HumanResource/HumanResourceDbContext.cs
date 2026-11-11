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
    public DbSet<ZhrOfficeNetwork> ZhrOfficeNetworks => Set<ZhrOfficeNetwork>();
    public DbSet<ZhrAttendanceEnforcement> ZhrAttendanceEnforcements => Set<ZhrAttendanceEnforcement>();
    public DbSet<ZhrOfficeLocation> ZhrOfficeLocations => Set<ZhrOfficeLocation>();
    public DbSet<ZhrTimeSetting> ZhrTimeSettings => Set<ZhrTimeSetting>();
    public DbSet<ZhrCompensationVersion> ZhrCompensationVersions => Set<ZhrCompensationVersion>();
    public DbSet<ZhrPayrollRun> ZhrPayrollRuns => Set<ZhrPayrollRun>();
    public DbSet<ZhrPayrollLine> ZhrPayrollLines => Set<ZhrPayrollLine>();
    public DbSet<ZhrWorkPattern> ZhrWorkPatterns => Set<ZhrWorkPattern>();
    public DbSet<ZhrPatternAssignment> ZhrPatternAssignments => Set<ZhrPatternAssignment>();
    public DbSet<ZhrShift> ZhrShifts => Set<ZhrShift>();
    public DbSet<ZhrShiftChange> ZhrShiftChanges => Set<ZhrShiftChange>();
    public DbSet<ZhrLeaveReconciliation> ZhrLeaveReconciliations => Set<ZhrLeaveReconciliation>();
    public DbSet<ZhrEmployeeStatusChange> ZhrEmployeeStatusChanges => Set<ZhrEmployeeStatusChange>();
    public DbSet<ZhrOffboardingCase> ZhrOffboardingCases => Set<ZhrOffboardingCase>();
    public DbSet<ZhrTimesheet> ZhrTimesheets => Set<ZhrTimesheet>();
    public DbSet<ZhrPayPeriodClosure> ZhrPayPeriodClosures => Set<ZhrPayPeriodClosure>();
    public DbSet<ZhrPayrollOneOff> ZhrPayrollOneOffs => Set<ZhrPayrollOneOff>();
    public DbSet<ZhrPayrollSettings> ZhrPayrollSettings => Set<ZhrPayrollSettings>();
    public DbSet<ZhrPayComponent> ZhrPayComponents => Set<ZhrPayComponent>();
    public DbSet<ZhrPayComponentAssignment> ZhrPayComponentAssignments => Set<ZhrPayComponentAssignment>();
    public DbSet<ZhrEmployeeLoan> ZhrEmployeeLoans => Set<ZhrEmployeeLoan>();
    public DbSet<ZhrPayGroup> ZhrPayGroups => Set<ZhrPayGroup>();
    public DbSet<ZhrPayGroupMember> ZhrPayGroupMembers => Set<ZhrPayGroupMember>();
    public DbSet<ZhrPayrollFiling> ZhrPayrollFilings => Set<ZhrPayrollFiling>();
    public DbSet<ZhrPackAcknowledgement> ZhrPackAcknowledgements => Set<ZhrPackAcknowledgement>();
    public DbSet<ZhrPackIssueReport> ZhrPackIssueReports => Set<ZhrPackIssueReport>();
    public DbSet<ZhrCountryCoverage> ZhrCountryCoverage => Set<ZhrCountryCoverage>();
    public DbSet<ZhrPaymentBatch> ZhrPaymentBatches => Set<ZhrPaymentBatch>();
    public DbSet<ZhrAlertAcknowledgement> ZhrAlertAcknowledgements => Set<ZhrAlertAcknowledgement>();
    public DbSet<ZhrSavedReport> ZhrSavedReports => Set<ZhrSavedReport>();
    public DbSet<ZhrAlertSetting> ZhrAlertSettings => Set<ZhrAlertSetting>();
    public DbSet<ZhrHiringRecord> ZhrHiringRecords => Set<ZhrHiringRecord>();
    public DbSet<ZhrCandidateLink> ZhrCandidateLinks => Set<ZhrCandidateLink>();
    public DbSet<ZhrPreHirePortal> ZhrPreHirePortals => Set<ZhrPreHirePortal>();
    public DbSet<ZhrAnnouncement> ZhrAnnouncements => Set<ZhrAnnouncement>();
    public DbSet<ZhrAnnouncementRead> ZhrAnnouncementReads => Set<ZhrAnnouncementRead>();
    public DbSet<ZhrAsset> ZhrAssets => Set<ZhrAsset>();
    public DbSet<ZhrSurvey> ZhrSurveys => Set<ZhrSurvey>();
    public DbSet<ZhrSurveyResponse> ZhrSurveyResponses => Set<ZhrSurveyResponse>();
    public DbSet<ZhrSurveyParticipation> ZhrSurveyParticipations => Set<ZhrSurveyParticipation>();
    public DbSet<ZhrGoal> ZhrGoals => Set<ZhrGoal>();
    public DbSet<ZhrGoalCheckIn> ZhrGoalCheckIns => Set<ZhrGoalCheckIn>();
    public DbSet<ZhrEmailMessage> ZhrEmailMessages => Set<ZhrEmailMessage>();
    public DbSet<ZhrExternalReturnFile> ZhrExternalReturnFiles => Set<ZhrExternalReturnFile>();
    public DbSet<ZhrCandidate> ZhrCandidates => Set<ZhrCandidate>();
    public DbSet<ZhrCoachingNote> ZhrCoachingNotes => Set<ZhrCoachingNote>();
    public DbSet<ZhrAttendanceCorrection> ZhrAttendanceCorrections => Set<ZhrAttendanceCorrection>();
    public DbSet<ZhrCompanyLocalization> ZhrCompanyLocalizations => Set<ZhrCompanyLocalization>();
    public DbSet<ZhrEmployeeIdFormat> ZhrEmployeeIdFormats => Set<ZhrEmployeeIdFormat>();
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

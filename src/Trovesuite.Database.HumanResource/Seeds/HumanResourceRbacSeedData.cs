using Trovesuite.Database.Common.Entities;
using Trovesuite.Database.CorePlatform.Entities;

namespace Trovesuite.Database.HumanResource.Seeds;

/// <summary>
/// HR + ZelosHR RBAC reference data (resource types, permissions, roles).
/// Seeded via EF in <see cref="HumanResourceRbacSeeder"/> — not raw SQL.
/// </summary>
public static class HumanResourceRbacSeedData
{
    public const string SystemTenantId = "system-tenant-id";
    public const string HrAdminRoleId = "role-subscribed-app-hr-admin";

    public static IReadOnlyList<ResourceType> ResourceTypes { get; } =
    [
        Rt("rt-subscribed-app-hr", "HR APP", "HR Subscribed APP", null),
        Rt("rt-hr-employees", "HR Employees", "Employees, including identity + employment fields", "rt-subscribed-app-hr"),
        Rt("rt-hr-departments", "HR Departments", "Department lookup", "rt-subscribed-app-hr"),
        Rt("rt-hr-banks", "HR Banks", "Bank + bank branch lookup", "rt-subscribed-app-hr"),
        Rt("rt-hr-pension", "HR Pension", "Pension providers (Tier 2 / Tier 3)", "rt-subscribed-app-hr"),
        Rt("rt-hr-files", "HR Files", "Documents uploaded against employees", "rt-subscribed-app-hr"),
        Rt("rt-zeloshr-dashboard", "ZelosHR Dashboard", "Executive HR dashboard", "rt-subscribed-app-hr"),
        Rt("rt-zeloshr-employee", "ZelosHR Employee", "Employee directory and profiles", "rt-subscribed-app-hr"),
        Rt("rt-zeloshr-org", "ZelosHR Org Structure", "Org chart and organisation summary", "rt-subscribed-app-hr"),
        Rt("rt-zeloshr-departments", "ZelosHR Departments", "Department management", "rt-subscribed-app-hr"),
        Rt("rt-zeloshr-branches", "ZelosHR Branches", "Branch management", "rt-subscribed-app-hr"),
        Rt("rt-zeloshr-lifecycle", "ZelosHR Lifecycle", "Lifecycle events and workflows", "rt-subscribed-app-hr"),
        Rt("rt-zeloshr-audit", "ZelosHR Audit", "Audit logs", "rt-subscribed-app-hr"),
        Rt("rt-zeloshr-attendance", "ZelosHR Attendance", "Attendance records", "rt-subscribed-app-hr"),
        Rt("rt-zeloshr-leave", "ZelosHR Leave", "Leave requests and balances", "rt-subscribed-app-hr"),
        Rt("rt-zeloshr-recruitment", "ZelosHR Recruitment", "Job postings", "rt-subscribed-app-hr"),
        Rt("rt-zeloshr-onboarding", "ZelosHR Onboarding", "Onboarding tasks", "rt-subscribed-app-hr"),
        Rt("rt-zeloshr-performance", "ZelosHR Performance", "Performance reviews", "rt-subscribed-app-hr"),
        Rt("rt-zeloshr-disciplinary", "ZelosHR Disciplinary", "Disciplinary cases", "rt-subscribed-app-hr"),
        Rt("rt-zeloshr-documents", "ZelosHR Documents", "Employee document metadata", "rt-subscribed-app-hr"),
        Rt("rt-zeloshr-custom-fields", "ZelosHR Custom Fields", "Tenant-defined fields and values", "rt-subscribed-app-hr"),
    ];

    public static IReadOnlyList<Permission> Permissions { get; } = BuildPermissions();

    public static IReadOnlyList<Role> Roles { get; } =
    [
        Role("role-subscribed-app-hr-admin", "HR Admin", "Administrator of the Human Resources system", "rt-subscribed-app-hr"),
        Role("role-zeloshr-dashboard-admin", "ZelosHR Dashboard Admin", "Administrator for HR dashboard", "rt-zeloshr-dashboard"),
        Role("role-zeloshr-employee-admin", "ZelosHR Employee Admin", "Administrator for employee management", "rt-zeloshr-employee"),
        Role("role-zeloshr-org-admin", "ZelosHR Org Admin", "Administrator for org chart and summary", "rt-zeloshr-org"),
        Role("role-zeloshr-departments-admin", "ZelosHR Departments Admin", "Administrator for departments", "rt-zeloshr-departments"),
        Role("role-zeloshr-branches-admin", "ZelosHR Branches Admin", "Administrator for branches", "rt-zeloshr-branches"),
        Role("role-zeloshr-lifecycle-admin", "ZelosHR Lifecycle Admin", "Administrator for lifecycle events", "rt-zeloshr-lifecycle"),
        Role("role-zeloshr-audit-admin", "ZelosHR Audit Admin", "Administrator for audit logs", "rt-zeloshr-audit"),
        Role("role-zeloshr-attendance-admin", "ZelosHR Attendance Admin", "Administrator for attendance", "rt-zeloshr-attendance"),
        Role("role-zeloshr-leave-admin", "ZelosHR Leave Admin", "Administrator for leave", "rt-zeloshr-leave"),
        Role("role-zeloshr-recruitment-admin", "ZelosHR Recruitment Admin", "Administrator for recruitment", "rt-zeloshr-recruitment"),
        Role("role-zeloshr-onboarding-admin", "ZelosHR Onboarding Admin", "Administrator for onboarding", "rt-zeloshr-onboarding"),
        Role("role-zeloshr-performance-admin", "ZelosHR Performance Admin", "Administrator for performance reviews", "rt-zeloshr-performance"),
        Role("role-zeloshr-disciplinary-admin", "ZelosHR Disciplinary Admin", "Administrator for disciplinary cases", "rt-zeloshr-disciplinary"),
        Role("role-zeloshr-documents-admin", "ZelosHR Documents Admin", "Administrator for employee documents", "rt-zeloshr-documents"),
        Role("role-zeloshr-custom-fields-admin", "ZelosHR Custom Fields Admin", "Administrator for custom fields", "rt-zeloshr-custom-fields"),
    ];

    static ResourceType Rt(string id, string name, string? description, string? parentId) =>
        new()
        {
            Id = id,
            ResourceTypeName = name,
            Description = description,
            ParentResourceId = parentId,
            DeleteStatus = DeleteStatuses.NotDeleted,
            IsActive = true,
        };

    static Role Role(string id, string name, string? description, string resourceTypeId) =>
        new()
        {
            Id = id,
            TenantId = SystemTenantId,
            RoleName = name,
            Description = description,
            ResourceTypeId = resourceTypeId,
            IsSystem = true,
            IsActive = true,
            DeleteStatus = DeleteStatuses.NotDeleted,
        };

    static IReadOnlyList<Permission> BuildPermissions()
    {
        var list = new List<Permission>();

        list.AddRange(HrCrud("employees", "HR Employees", "rt-hr-employees",
            ("create", "Create employees (onboarding mega-endpoint)"),
            ("get", "View / list / read employees, view statistics"),
            ("update", "Update non-sensitive employee fields, reporting line, emergency contacts, documents"),
            ("delete", "Soft / permanent delete + restore employees"),
            ("admin", "Full employee administration including lifecycle overrides")));
        list.Add(Perm("permission-hr-employees-reveal-sensitive", "HR Employees Reveal Sensitive", "rt-hr-employees",
            "View unmasked SSNIT, TIN, national-ID and bank account numbers"));
        list.Add(Perm("permission-hr-employees-manage-salary", "HR Employees Manage Salary", "rt-hr-employees",
            "Append / update salary history (raises, promotions, corrections)"));

        list.AddRange(HrCrud("departments", "HR Departments", "rt-hr-departments",
            ("create", "Create departments"),
            ("get", "View and list departments"),
            ("update", "Update departments"),
            ("delete", "Archive or delete departments"),
            ("admin", "Full department administration")));

        list.AddRange(HrCrud("banks", "HR Banks", "rt-hr-banks",
            ("create", "Create banks and bank branches"),
            ("get", "View and list banks and branches"),
            ("update", "Update banks and bank branches"),
            ("delete", "Delete banks and bank branches"),
            ("admin", "Full bank administration")));

        list.AddRange(HrCrud("pension-providers", "HR Pension Providers", "rt-hr-pension",
            ("create", "Create Tier 2 and Tier 3 pension providers"),
            ("get", "View and list pension providers"),
            ("update", "Update pension providers"),
            ("delete", "Delete pension providers"),
            ("admin", "Full pension provider administration")));

        list.AddRange(HrCrud("files", "HR Files", "rt-hr-files",
            ("create", "Upload employee documents"),
            ("get", "View and list employee documents"),
            ("update", "Update employee document metadata"),
            ("delete", "Delete employee documents"),
            ("admin", "Full employee file administration")));

        list.AddRange(ZelosCrud("dashboard", "Dashboard", "rt-zeloshr-dashboard",
            ("create", "Create dashboard widgets and layouts"),
            ("get", "View dashboard summary and KPIs"),
            ("update", "Update dashboard widgets and layouts"),
            ("delete", "Delete dashboard widgets and layouts"),
            ("admin", "Full dashboard administration")));

        list.AddRange(ZelosCrud("employee", "Employee", "rt-zeloshr-employee",
            ("create", "Create employee records"),
            ("get", "List and read employees and directory"),
            ("update", "Update employee records"),
            ("delete", "Soft-delete employee records"),
            ("admin", "Full employee administration")));

        list.AddRange(ZelosCrud("org", "Org", "rt-zeloshr-org",
            ("create", "Create org structure aggregates"),
            ("get", "View org chart and organisation summary"),
            ("update", "Update org structure aggregates"),
            ("delete", "Delete org structure aggregates"),
            ("admin", "Full org structure administration")));

        list.AddRange(ZelosCrud("departments", "Departments", "rt-zeloshr-departments",
            ("create", "Create departments"),
            ("get", "List and read departments"),
            ("update", "Update departments"),
            ("delete", "Archive departments"),
            ("admin", "Full department administration")));

        list.AddRange(ZelosCrud("branches", "Branches", "rt-zeloshr-branches",
            ("create", "Create branches"),
            ("get", "List and read branches"),
            ("update", "Update branches"),
            ("delete", "Archive branches"),
            ("admin", "Full branch administration")));

        list.AddRange(ZelosCrud("lifecycle", "Lifecycle", "rt-zeloshr-lifecycle",
            ("create", "Create lifecycle events"),
            ("get", "List and read lifecycle events"),
            ("update", "Update lifecycle events"),
            ("delete", "Delete lifecycle events"),
            ("admin", "Full lifecycle administration")));

        list.AddRange(ZelosCrud("audit", "Audit", "rt-zeloshr-audit",
            ("create", "Create audit log entries"),
            ("get", "List and read audit logs"),
            ("update", "Update audit log entries"),
            ("delete", "Delete audit log entries"),
            ("admin", "Full audit log administration")));

        list.AddRange(ZelosCrud("attendance", "Attendance", "rt-zeloshr-attendance",
            ("create", "Record attendance"),
            ("get", "List and read attendance records"),
            ("update", "Update attendance records"),
            ("delete", "Delete attendance records"),
            ("admin", "Full attendance administration")));

        list.AddRange(ZelosCrud("leave", "Leave", "rt-zeloshr-leave",
            ("create", "Submit leave requests"),
            ("get", "List leave requests and balances"),
            ("update", "Update and approve leave requests"),
            ("delete", "Delete leave requests"),
            ("admin", "Full leave administration")));

        list.AddRange(ZelosCrud("recruitment", "Recruitment", "rt-zeloshr-recruitment",
            ("create", "Create job postings"),
            ("get", "List and read job postings"),
            ("update", "Update job postings"),
            ("delete", "Delete job postings"),
            ("admin", "Full recruitment administration")));

        list.AddRange(ZelosCrud("onboarding", "Onboarding", "rt-zeloshr-onboarding",
            ("create", "Assign onboarding tasks"),
            ("get", "List onboarding tasks"),
            ("update", "Update and complete onboarding tasks"),
            ("delete", "Delete onboarding tasks"),
            ("admin", "Full onboarding administration")));

        list.AddRange(ZelosCrud("performance", "Performance", "rt-zeloshr-performance",
            ("create", "Create performance reviews"),
            ("get", "List performance reviews"),
            ("update", "Update and complete performance reviews"),
            ("delete", "Delete performance reviews"),
            ("admin", "Full performance administration")));

        list.AddRange(ZelosCrud("disciplinary", "Disciplinary", "rt-zeloshr-disciplinary",
            ("create", "Open disciplinary cases"),
            ("get", "List disciplinary cases"),
            ("update", "Update disciplinary cases"),
            ("delete", "Delete disciplinary cases"),
            ("admin", "Full disciplinary administration")));

        list.AddRange(ZelosCrud("documents", "Documents", "rt-zeloshr-documents",
            ("create", "Upload document metadata"),
            ("get", "List employee documents"),
            ("update", "Update document metadata"),
            ("delete", "Delete document metadata"),
            ("admin", "Full document administration")));

        list.AddRange(ZelosCrud("custom-fields", "Custom Fields", "rt-zeloshr-custom-fields",
            ("create", "Create custom field definitions"),
            ("get", "View custom field definitions and form schema"),
            ("update", "Update custom field definitions"),
            ("delete", "Soft-delete custom field definitions"),
            ("admin", "Reorder and administer custom field definitions")));

        list.AddRange(ZelosCrud("custom-field-values", "Custom Field Values", "rt-zeloshr-custom-fields",
            ("create", "Create custom field values on entities"),
            ("get", "Read custom field values on entities"),
            ("update", "Write custom field values on entities"),
            ("delete", "Clear custom field values on entities"),
            ("admin", "Full custom field value administration")));

        list.Add(Perm("permission-zeloshr-sensitive-fields-reveal", "ZelosHR Sensitive Fields Reveal", "rt-zeloshr-custom-fields",
            "Reveal masked sensitive custom field values"));

        return list;
    }

    static IEnumerable<Permission> HrCrud(string slug, string label, string resourceTypeId,
        params (string verb, string description)[] verbs)
    {
        foreach (var (verb, description) in verbs)
        {
            var verbTitle = char.ToUpper(verb[0]) + verb[1..];
            yield return Perm(
                $"permission-hr-{slug}-{verb}",
                $"HR {label} {verbTitle}",
                resourceTypeId,
                description);
        }
    }

    static IEnumerable<Permission> ZelosCrud(string slug, string label, string resourceTypeId,
        params (string verb, string description)[] verbs)
    {
        foreach (var (verb, description) in verbs)
        {
            var verbTitle = char.ToUpper(verb[0]) + verb[1..];
            yield return Perm(
                $"permission-zeloshr-{slug}-{verb}",
                $"ZelosHR {label} {verbTitle}",
                resourceTypeId,
                description);
        }
    }

    static Permission Perm(string id, string name, string resourceTypeId, string? description) =>
        new()
        {
            Id = id,
            PermissionName = name,
            ResourceTypeId = resourceTypeId,
            Description = description,
            DeleteStatus = DeleteStatuses.NotDeleted,
            IsActive = true,
        };
}

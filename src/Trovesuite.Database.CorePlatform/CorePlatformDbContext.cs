using Microsoft.EntityFrameworkCore;
using Trovesuite.Database.CorePlatform.Entities;

namespace Trovesuite.Database.CorePlatform;

public class CorePlatformDbContext : DbContext
{
    public const string SchemaName = "core_platform";

    public CorePlatformDbContext(DbContextOptions<CorePlatformDbContext> options) : base(options) { }

    // Tenants & ownership
    public DbSet<Tenant> Tenants => Set<Tenant>();
    public DbSet<TenantOwnerRegistryEntry> TenantOwnersRegistry => Set<TenantOwnerRegistryEntry>();

    // Users
    public DbSet<User> Users => Set<User>();
    public DbSet<Member> Members => Set<Member>();
    public DbSet<Otp> Otps => Set<Otp>();
    public DbSet<PasswordPolicy> PasswordPolicies => Set<PasswordPolicy>();
    public DbSet<MultiFactorSetting> MultiFactorSettings => Set<MultiFactorSetting>();
    public DbSet<ChangePasswordPolicy> ChangePasswordPolicies => Set<ChangePasswordPolicy>();
    public DbSet<UserLoginTracking> UserLoginTracking => Set<UserLoginTracking>();
    public DbSet<EnterpriseSubscription> EnterpriseSubscriptions => Set<EnterpriseSubscription>();
    public DbSet<ReferralPartner> ReferralPartners => Set<ReferralPartner>();

    // Access control
    public DbSet<ResourceType> ResourceTypes => Set<ResourceType>();
    public DbSet<SharedResourceId> SharedResourceIds => Set<SharedResourceId>();
    public DbSet<Permission> Permissions => Set<Permission>();
    public DbSet<Role> Roles => Set<Role>();
    public DbSet<RolePermission> RolePermissions => Set<RolePermission>();
    public DbSet<AssignRole> AssignRoles => Set<AssignRole>();

    // Subscriptions
    public DbSet<Subscription> Subscriptions => Set<Subscription>();
    public DbSet<App> Apps => Set<App>();
    public DbSet<AppTierConfig> AppTierConfigs => Set<AppTierConfig>();
    public DbSet<AppFeature> AppFeatures => Set<AppFeature>();
    public DbSet<AppSubscription> AppSubscriptions => Set<AppSubscription>();
    public DbSet<AppSubscriptionHistory> AppSubscriptionHistories => Set<AppSubscriptionHistory>();
    public DbSet<PaymentAuthorization> PaymentAuthorizations => Set<PaymentAuthorization>();

    // Organizations
    public DbSet<Group> Groups => Set<Group>();
    public DbSet<UserGroup> UserGroups => Set<UserGroup>();
    public DbSet<LoginSetting> LoginSettings => Set<LoginSetting>();
    public DbSet<Organization> Organizations => Set<Organization>();
    public DbSet<Business> Businesses => Set<Business>();
    public DbSet<BusinessApp> BusinessApps => Set<BusinessApp>();
    public DbSet<Location> Locations => Set<Location>();
    public DbSet<BusinessAppLocation> BusinessAppLocations => Set<BusinessAppLocation>();
    public DbSet<UserLocation> UserLocations => Set<UserLocation>();
    public DbSet<GroupLocation> GroupLocations => Set<GroupLocation>();

    // Misc
    public DbSet<ResourceDeletionChatHistory> ResourceDeletionChatHistories => Set<ResourceDeletionChatHistory>();
    public DbSet<ActivityLog> ActivityLogs => Set<ActivityLog>();
    public DbSet<UnitOfMeasure> UnitOfMeasures => Set<UnitOfMeasure>();
    public DbSet<Currency> Currencies => Set<Currency>();
    public DbSet<Theme> Themes => Set<Theme>();
    public DbSet<Expense> Expenses => Set<Expense>();
    public DbSet<DocumentPath> DocumentPaths => Set<DocumentPath>();
    public DbSet<BillingLog> BillingLogs => Set<BillingLog>();
    public DbSet<ExpenseHistory> ExpensesHistory => Set<ExpenseHistory>();
    public DbSet<NotificationEmailCredential> NotificationEmailCredentials => Set<NotificationEmailCredential>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasDefaultSchema(SchemaName);
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(CorePlatformDbContext).Assembly);
        base.OnModelCreating(modelBuilder);
    }
}

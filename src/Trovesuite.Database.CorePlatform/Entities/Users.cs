using Trovesuite.Database.Common.Entities;

namespace Trovesuite.Database.CorePlatform.Entities;

public class User : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string Fullname { get; set; } = default!;
    public string Email { get; set; } = default!;
    public string Contact { get; set; } = default!;
    public bool IsOwner { get; set; }

    public string? Gender { get; set; }
    public string? Dob { get; set; }
    public string? Address { get; set; }
    public string? ProfilePic { get; set; }
    public string? LoginPassword { get; set; }
    public bool CanLogin { get; set; }
}

public class Member : TenantScopedEntity
{
    public string Id { get; set; } = default!;
    public string UserId { get; set; } = default!;
}

public class Otp
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string? OtpCode { get; set; }
    public bool IsActive { get; set; }
    public string? Description { get; set; }
    public string Email { get; set; } = default!;
    public string? Contact { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
}

public class PasswordPolicy
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public bool EnforcePasswordPolicy { get; set; }
    public int MinLength { get; set; } = 8;
    public bool RequireUppercase { get; set; } = true;
    public bool RequireLowercase { get; set; } = true;
    public bool RequireNumbers { get; set; } = true;
    public bool RequireSpecialChars { get; set; } = true;
    public string? SpecialCharsList { get; set; } = "!@#$%^&*()_+-=[]{}|;:,.<>?";
    public bool IsActive { get; set; } = true;
    public string? Description { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class MultiFactorSetting
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public bool IsMultiFactor { get; set; }
    public bool IsActive { get; set; } = true;
    public string? Description { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class ChangePasswordPolicy
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public bool AllowPasswordChange { get; set; } = true;
    public string? Description { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class UserLoginTracking
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string UserId { get; set; } = default!;
    public int LoginAttemptsCount { get; set; }
    public DateTimeOffset? LastFailedLoginAttempt { get; set; }
    public DateTimeOffset? LastSuccessfulLogin { get; set; }
    public DateTimeOffset? PasswordLastChanged { get; set; }
    public DateTimeOffset? PasswordExpiryDate { get; set; }
    public string[]? PasswordHistory { get; set; }
    public bool IsLocked { get; set; }
    public DateTimeOffset? LockedUntil { get; set; }
    public bool IsActive { get; set; } = true;
    public string? Description { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class EnterpriseSubscription
{
    public string Id { get; set; } = default!;
    public string Fullname { get; set; } = default!;
    public string Email { get; set; } = default!;
    public string Contact { get; set; } = default!;
    public string CompanyName { get; set; } = default!;
    public string? Description { get; set; }
    public string DeleteStatus { get; set; } = DeleteStatuses.NotDeleted;
    public bool IsActive { get; set; } = true;
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

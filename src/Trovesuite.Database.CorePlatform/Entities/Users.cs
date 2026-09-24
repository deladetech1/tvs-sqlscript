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

    // ---- Reuse ----------------------------------------------------------
    // Whether somebody may set a password they have used before. On by
    // default: this is how the platform has always behaved, and turning it
    // off for everyone at once would refuse the next password change of
    // every user who happens to cycle between two.
    public bool AllowPasswordReuse { get; set; } = true;
    /// How many previous passwords to remember and refuse, once reuse is off.
    public int PasswordHistoryCount { get; set; } = 5;
    public bool ReuseAppliesToOwner { get; set; }

    // ---- Expiry ---------------------------------------------------------
    // Off by default, and gated by its OWN flag rather than by
    // EnforcePasswordPolicy — a tenant can want rotation without wanting
    // complexity rules, and folding the two together silently gives them
    // neither.
    public bool EnforcePasswordExpiry { get; set; }
    public int PasswordExpiryValue { get; set; } = 90;
    /// DAYS, WEEKS, MONTHS, QUARTERS, SEMI_ANNUAL or YEARS. QUARTERS and
    /// SEMI_ANNUAL are kept as units in their own right rather than folded
    /// into "3 months" and "6 months", so the interval an admin picked is the
    /// interval the screen shows them afterwards.
    public string PasswordExpiryUnit { get; set; } = "DAYS";
    public bool ExpiryAppliesToOwner { get; set; }

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

/// <summary>
/// The clock a tenant's login schedules are read against.
///
/// Everything else in this schema is an absolute instant, so it never needed
/// one. A weekly window does: "Monday 02:30 to 17:50" is not a moment until you
/// say whose 02:30. Stored as an IANA name (Africa/Accra, Europe/London) rather
/// than an offset, so daylight saving is the zone database's problem and not a
/// column somebody has to remember to change twice a year.
/// </summary>
public class TimezoneSetting
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string Timezone { get; set; } = "UTC";
    public bool IsActive { get; set; } = true;
    public string? Description { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>
/// How long a signed-in session lasts before the user has to sign in again.
///
/// This was the constant ACCESS_TOKEN_EXPIRE_HOUR = 24 in the login service:
/// every tenant got the same day-long session whether they were a two-person
/// shop or a bank. The number moves here so each tenant can shorten it.
///
/// Stored in minutes rather than hours. The behaviour being replaced is exactly
/// 1440 of them, and minutes leave room for the tenant who wants a half-hour
/// session without another migration to get there.
///
/// Note what this cannot do: the timeout is baked into a stateless JWT's `exp`
/// at sign-in, so lowering it shortens the NEXT session, not the ones already
/// handed out.
/// </summary>
public class SessionSetting
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public int SessionTimeoutMinutes { get; set; } = 1440;
    /// Whether the tenant owner's sessions are cut short too. Off by default,
    /// like every other owner switch here.
    public bool AppliesToOwner { get; set; }
    public bool IsActive { get; set; } = true;
    public string? Description { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>
/// Locking an account after repeated failed sign-ins.
///
/// Off by default — switching it on for existing tenants without being asked
/// would start locking people out of a system that has never done that.
///
/// ReleaseMode is an explicit choice rather than "a duration of zero means
/// manual". A 0 in a field called lockout_duration_minutes reads as "unlock
/// immediately" to the next person who sees it, which is the opposite of what
/// it would mean.
/// </summary>
public class AccountLockoutSetting
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public bool IsEnabled { get; set; }
    /// Consecutive failures that trip the lock.
    public int MaxFailedAttempts { get; set; } = 5;
    /// AUTOMATIC — the lock expires on its own after LockoutDurationMinutes.
    /// MANUAL — it holds until an admin opens the account.
    public string ReleaseMode { get; set; } = "AUTOMATIC";
    /// Read only when ReleaseMode is AUTOMATIC.
    public int LockoutDurationMinutes { get; set; } = 30;
    /// Whether the tenant owner can be locked out. Off by default: an owner
    /// who locks themselves out of their own tenant has nobody above them to
    /// let them back in.
    public bool AppliesToOwner { get; set; }
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

/// <summary>
/// One row per user, carrying everything the login and password policies need
/// to remember about them between sign-ins.
///
/// The table was created years ago and then never written to — no code read or
/// wrote a single column until account lockout, password reuse and password
/// expiry were made configurable. The columns below were already here and are
/// now live; the lock_reason / locked_at / unlocked_* group is new, and exists
/// so an admin looking at a locked account can see why it locked before
/// deciding to open it again.
/// </summary>
public class UserLoginTracking
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string UserId { get; set; } = default!;
    /// Consecutive failures. Reset to 0 by a successful sign-in, so somebody
    /// who mistypes twice a week is never locked out.
    public int LoginAttemptsCount { get; set; }
    public DateTimeOffset? LastFailedLoginAttempt { get; set; }
    public DateTimeOffset? LastSuccessfulLogin { get; set; }
    public DateTimeOffset? PasswordLastChanged { get; set; }
    public DateTimeOffset? PasswordExpiryDate { get; set; }
    /// Trailing bcrypt hashes, newest first, trimmed to the policy's
    /// PasswordHistoryCount. Hashes, never passwords.
    public string[]? PasswordHistory { get; set; }
    public bool IsLocked { get; set; }
    /// When an automatic lock frees itself. NULL while locked means the lock
    /// is held until an admin opens it — the policy's MANUAL release mode.
    public DateTimeOffset? LockedUntil { get; set; }

    /// Why the account locked, in the words the admin screen shows.
    public string? LockReason { get; set; }
    public DateTimeOffset? LockedAt { get; set; }
    /// Who opened it: a user id, or "system" when the lock simply expired.
    public string? UnlockedBy { get; set; }
    public DateTimeOffset? UnlockedAt { get; set; }

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

// Referral Partner Programme — public "Expression of Interest" submissions from
// the landing page. Like EnterpriseSubscription this is a tenant-less lead capture
// table (no tenant_id, bare audit text columns).
public class ReferralPartner
{
    public string Id { get; set; } = default!;
    public string Fullname { get; set; } = default!;
    public string Email { get; set; } = default!;
    public string WhatsappNumber { get; set; } = default!;
    // Country & residential address, captured as a single free-text field on the form.
    public string Address { get; set; } = default!;
    public string Profession { get; set; } = default!;
    // Which product(s) the partner would refer: LOANDRIFT | MYSTOREGUARD | BOTH.
    public string Products { get; set; } = default!;
    // Confirms interest in the programme and consent to be contacted.
    public bool Consent { get; set; }
    public string DeleteStatus { get; set; } = DeleteStatuses.NotDeleted;
    public bool IsActive { get; set; } = true;
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

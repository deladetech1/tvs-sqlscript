namespace Trovesuite.Database.MyStoreGuard.Entities;

public class MsgMessage
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string Subject { get; set; } = default!;
    public string Body { get; set; } = default!;
    public string Channel { get; set; } = "SMS";
    public string RecipientType { get; set; } = default!;
    public DateTimeOffset? ScheduledAt { get; set; }
    public string Status { get; set; } = "DRAFT";
    public DateTimeOffset? SentAt { get; set; }
    public DateTimeOffset? PickedUpAt { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

public class MsgMessageRecipient
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string MessageId { get; set; } = default!;
    public string RecipientType { get; set; } = default!;
    public string RecipientId { get; set; } = default!;
    public string? RecipientName { get; set; }
    public string? RecipientEmail { get; set; }
    public string? RecipientContact { get; set; }
    public string Status { get; set; } = "PENDING";
    public string? FailureReason { get; set; }
    public DateTimeOffset? DeliveredAt { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
}

public class Meeting
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string Title { get; set; } = default!;
    public string? Description { get; set; }
    public string? Location { get; set; }
    public string MeetingDate { get; set; } = default!;
    public string StartTime { get; set; } = default!;
    public string? EndTime { get; set; }
    public DateTimeOffset StartDatetime { get; set; }
    public DateTimeOffset? EndDatetime { get; set; }
    public string ParticipantType { get; set; } = default!;
    public int ReminderMinutes { get; set; } = 30;
    public string ReminderChannel { get; set; } = "SMS";
    public string Status { get; set; } = "SCHEDULED";
    public DateTimeOffset? ReminderPickedUpAt { get; set; }
    public DateTimeOffset? ReminderSentAt { get; set; }
    public string? Notes { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

public class MeetingParticipant
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string MeetingId { get; set; } = default!;
    public string ParticipantType { get; set; } = default!;
    public string ParticipantId { get; set; } = default!;
    public string? ParticipantName { get; set; }
    public string? ParticipantEmail { get; set; }
    public string? ParticipantContact { get; set; }
    public string RsvpStatus { get; set; } = "PENDING";
    public string ReminderStatus { get; set; } = "PENDING";
    public string? ReminderFailureReason { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
}

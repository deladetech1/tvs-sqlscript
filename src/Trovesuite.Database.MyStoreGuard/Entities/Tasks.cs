namespace Trovesuite.Database.MyStoreGuard.Entities;

// =====================================================
// WORKFLOW TEMPLATES (business-scoped, reusable)
// =====================================================

public class MsgWorkflowTemplate
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string Name { get; set; } = default!;
    public string TemplateType { get; set; } = "OTHERS";
    public string? Description { get; set; }
    public bool IsActive { get; set; } = true;
    public string DeleteStatus { get; set; } = "NOT_DELETED";
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

public class MsgWorkflowTemplateStep
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string TemplateId { get; set; } = default!;
    public string Name { get; set; } = default!;
    public string? Description { get; set; }
    public int DisplayOrder { get; set; } = 0;
    public string? DefaultLocationId { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

public class MsgWorkflowTemplateStepDep
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string StepId { get; set; } = default!;
    public string DependsOnStepId { get; set; } = default!;
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
}

public class MsgWorkflowTemplateStepTarget
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string StepId { get; set; } = default!;
    public string TargetKind { get; set; } = default!;   // ASSIGNEE | APPROVER
    public string TargetType { get; set; } = default!;   // USER | GROUP
    public string TargetId { get; set; } = default!;     // cp_users.id or cp_groups.id (polymorphic, no FK)
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
}

// =====================================================
// TASKS / JOBS (business-scoped instances)
// =====================================================

public class MsgTask
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string Title { get; set; } = default!;
    public string? Description { get; set; }
    public string TaskType { get; set; } = "OTHERS";
    public string? CustomerId { get; set; }
    public string? TemplateId { get; set; }
    public string? OriginLocationId { get; set; }
    public string Status { get; set; } = "ACTIVE";   // ACTIVE | COMPLETED | CANCELLED
    public DateTimeOffset? DueDate { get; set; }
    public string DeleteStatus { get; set; } = "NOT_DELETED";
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

public class MsgTaskStep
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string TaskId { get; set; } = default!;
    public string Name { get; set; } = default!;
    public string? Description { get; set; }
    public int DisplayOrder { get; set; } = 0;
    public string? LocationId { get; set; }
    public string Status { get; set; } = "TODO";   // TODO | IN_PROGRESS | DONE | COMPLETED | CANCELLED
    public string? ClaimedBy { get; set; }
    public DateTimeOffset? ClaimedAt { get; set; }
    public string? DoneBy { get; set; }
    public DateTimeOffset? DoneAt { get; set; }
    public string? CompletedBy { get; set; }
    public DateTimeOffset? CompletedAt { get; set; }
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

public class MsgTaskStepDep
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string StepId { get; set; } = default!;
    public string DependsOnStepId { get; set; } = default!;
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
}

public class MsgTaskStepTarget
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string StepId { get; set; } = default!;
    public string TargetKind { get; set; } = default!;   // ASSIGNEE | APPROVER
    public string TargetType { get; set; } = default!;   // USER | GROUP
    public string TargetId { get; set; } = default!;     // cp_users.id or cp_groups.id (polymorphic, no FK)
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
}

// =====================================================
// NOTIFICATIONS
// =====================================================

public class MsgTaskNotificationSetting
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string UserId { get; set; } = default!;
    public bool OptIn { get; set; } = true;
    public int ReminderIntervalMinutes { get; set; } = 120;
    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public string? DeletedBy { get; set; }
}

public class MsgTaskNotification
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string TaskId { get; set; } = default!;
    public string? StepId { get; set; }
    public string RecipientUserId { get; set; } = default!;
    public string Kind { get; set; } = default!;        // ASSIGNED | READY | DONE_NEEDS_APPROVAL | REMINDER
    public string Status { get; set; } = "PENDING";     // PENDING | SENT | FAILED
    public DateTimeOffset? PickedUpAt { get; set; }
    public DateTimeOffset? SentAt { get; set; }
    public DateTimeOffset? NextRemindAt { get; set; }
    public string? FailureReason { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
}

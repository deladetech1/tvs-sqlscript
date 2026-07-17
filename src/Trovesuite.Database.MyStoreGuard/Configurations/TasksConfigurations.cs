using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.Common.Conventions;
using Trovesuite.Database.CorePlatform.Configurations;
using Trovesuite.Database.CorePlatform.Entities;
using Trovesuite.Database.MyStoreGuard.Entities;

namespace Trovesuite.Database.MyStoreGuard.Configurations;

// =====================================================
// WORKFLOW TEMPLATES
// =====================================================

public sealed class MsgWorkflowTemplateConfiguration : IEntityTypeConfiguration<MsgWorkflowTemplate>
{
    public void Configure(EntityTypeBuilder<MsgWorkflowTemplate> b)
    {
        b.ToTable("msg_workflow_templates");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Name).HasColumnType("varchar(255)");
        b.Property(x => x.TemplateType).HasDefaultValue("OTHERS");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.HasInCheck("template_type", "SALES", "SERVICE", "DELIVERY", "INSTALLATION", "CONSULTATION", "OTHERS");
        b.HasDeleteStatusCheck();
        b.WithTenantOrgBusFks();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class MsgWorkflowTemplateStepConfiguration : IEntityTypeConfiguration<MsgWorkflowTemplateStep>
{
    public void Configure(EntityTypeBuilder<MsgWorkflowTemplateStep> b)
    {
        b.ToTable("msg_workflow_template_steps");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Name).HasColumnType("varchar(255)");
        b.Property(x => x.DisplayOrder).HasDefaultValue(0);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.WithTenantOrgBusFks();
        b.HasOne<MsgWorkflowTemplate>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "TemplateId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.WithCompositeFk<MsgWorkflowTemplateStep, Location>("DefaultLocationId", DeleteBehavior.Restrict);
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class MsgWorkflowTemplateStepDepConfiguration : IEntityTypeConfiguration<MsgWorkflowTemplateStepDep>
{
    public void Configure(EntityTypeBuilder<MsgWorkflowTemplateStepDep> b)
    {
        b.ToTable("msg_workflow_template_step_deps");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.StepId, x.DependsOnStepId }).IsUnique();
        b.WithTenantOrgBusFks();
        b.HasOne<MsgWorkflowTemplateStep>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "StepId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.HasOne<MsgWorkflowTemplateStep>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "DependsOnStepId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Restrict);
        b.HasOne<User>().WithMany().HasForeignKey("CreatedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId)).OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class MsgWorkflowTemplateStepTargetConfiguration : IEntityTypeConfiguration<MsgWorkflowTemplateStepTarget>
{
    public void Configure(EntityTypeBuilder<MsgWorkflowTemplateStepTarget> b)
    {
        b.ToTable("msg_workflow_template_step_targets");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.HasInCheck("target_kind", "ASSIGNEE", "APPROVER");
        b.HasInCheck("target_type", "USER", "GROUP");
        b.WithTenantOrgBusFks();
        b.HasOne<MsgWorkflowTemplateStep>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "StepId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.HasOne<User>().WithMany().HasForeignKey("CreatedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId)).OnDelete(DeleteBehavior.Restrict);
    }
}

// =====================================================
// TASKS / JOBS
// =====================================================

public sealed class MsgTaskConfiguration : IEntityTypeConfiguration<MsgTask>
{
    public void Configure(EntityTypeBuilder<MsgTask> b)
    {
        b.ToTable("msg_tasks");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Title).HasColumnType("varchar(255)");
        b.Property(x => x.TaskType).HasDefaultValue("OTHERS");
        b.Property(x => x.Status).HasDefaultValue("ACTIVE");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.HasInCheck("task_type", "SALES", "SERVICE", "DELIVERY", "INSTALLATION", "CONSULTATION", "OTHERS");
        b.HasInCheck("status", "ACTIVE", "COMPLETED", "CANCELLED");
        b.HasDeleteStatusCheck();
        b.WithTenantOrgBusFks();
        // Restrict (not SetNull): the customer FK spans TenantId/OrgId/BusId,
        // which are part of the task PK and NOT NULL — SetNull would fail.
        b.WithCustomerFk(DeleteBehavior.Restrict);
        b.WithCompositeFk<MsgTask, MsgWorkflowTemplate>("TemplateId", DeleteBehavior.Restrict);
        b.WithCompositeFk<MsgTask, Location>("OriginLocationId", DeleteBehavior.Restrict);
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class MsgTaskStepConfiguration : IEntityTypeConfiguration<MsgTaskStep>
{
    public void Configure(EntityTypeBuilder<MsgTaskStep> b)
    {
        b.ToTable("msg_task_steps");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Name).HasColumnType("varchar(255)");
        b.Property(x => x.DisplayOrder).HasDefaultValue(0);
        b.Property(x => x.Status).HasDefaultValue("TODO");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.HasInCheck("status", "TODO", "IN_PROGRESS", "DONE", "COMPLETED", "CANCELLED");
        b.WithTenantOrgBusFks();
        b.HasOne<MsgTask>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "TaskId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.WithCompositeFk<MsgTaskStep, Location>("LocationId", DeleteBehavior.Restrict);
        b.HasOne<User>().WithMany().HasForeignKey("ClaimedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId)).OnDelete(DeleteBehavior.Restrict);
        b.HasOne<User>().WithMany().HasForeignKey("DoneBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId)).OnDelete(DeleteBehavior.Restrict);
        b.HasOne<User>().WithMany().HasForeignKey("CompletedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId)).OnDelete(DeleteBehavior.Restrict);
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class MsgTaskStepDepConfiguration : IEntityTypeConfiguration<MsgTaskStepDep>
{
    public void Configure(EntityTypeBuilder<MsgTaskStepDep> b)
    {
        b.ToTable("msg_task_step_deps");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.StepId, x.DependsOnStepId }).IsUnique();
        b.WithTenantOrgBusFks();
        b.HasOne<MsgTaskStep>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "StepId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.HasOne<MsgTaskStep>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "DependsOnStepId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Restrict);
        b.HasOne<User>().WithMany().HasForeignKey("CreatedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId)).OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class MsgTaskStepTargetConfiguration : IEntityTypeConfiguration<MsgTaskStepTarget>
{
    public void Configure(EntityTypeBuilder<MsgTaskStepTarget> b)
    {
        b.ToTable("msg_task_step_targets");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.HasInCheck("target_kind", "ASSIGNEE", "APPROVER");
        b.HasInCheck("target_type", "USER", "GROUP");
        b.WithTenantOrgBusFks();
        b.HasOne<MsgTaskStep>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "StepId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.HasOne<User>().WithMany().HasForeignKey("CreatedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId)).OnDelete(DeleteBehavior.Restrict);
    }
}

// =====================================================
// NOTIFICATIONS
// =====================================================

public sealed class MsgTaskNotificationSettingConfiguration : IEntityTypeConfiguration<MsgTaskNotificationSetting>
{
    public void Configure(EntityTypeBuilder<MsgTaskNotificationSetting> b)
    {
        b.ToTable("msg_task_notification_settings");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.OptIn).HasDefaultValue(true);
        b.Property(x => x.ReminderIntervalMinutes).HasDefaultValue(120);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.UserId }).IsUnique();
        b.WithTenantOrgBusFks();
        b.HasOne<User>().WithMany().HasForeignKey("UserId", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId)).OnDelete(DeleteBehavior.Cascade);
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class MsgTaskNotificationConfiguration : IEntityTypeConfiguration<MsgTaskNotification>
{
    public void Configure(EntityTypeBuilder<MsgTaskNotification> b)
    {
        b.ToTable("msg_task_notifications");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Status).HasDefaultValue("PENDING");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.HasInCheck("kind", "ASSIGNED", "READY", "DONE_NEEDS_APPROVAL", "REMINDER", "MENTIONED");
        b.HasInCheck("status", "PENDING", "SENT", "FAILED");
        b.HasIndex(x => new { x.Status, x.PickedUpAt });
        b.WithTenantOrgBusFks();
        b.HasOne<MsgTask>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "TaskId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.HasOne<MsgTaskStep>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "StepId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.HasOne<User>().WithMany().HasForeignKey("RecipientUserId", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId)).OnDelete(DeleteBehavior.Restrict);
        b.HasOne<User>().WithMany().HasForeignKey("CreatedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId)).OnDelete(DeleteBehavior.Restrict);
    }
}

// =====================================================
// COMMENTS / ATTACHMENTS / MENTIONS
// =====================================================

public sealed class MsgTaskCommentConfiguration : IEntityTypeConfiguration<MsgTaskComment>
{
    public void Configure(EntityTypeBuilder<MsgTaskComment> b)
    {
        b.ToTable("msg_task_comments");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Body).HasColumnType("text");
        b.Property(x => x.EditedAt).HasColumnType("timestamptz");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.StepId });
        b.WithTenantOrgBusFks();
        b.HasOne<MsgTaskStep>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "StepId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.HasOne<MsgTask>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "TaskId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.WithCrossSchemaCreateUpdateUserFks();
    }
}

public sealed class MsgTaskCommentMentionConfiguration : IEntityTypeConfiguration<MsgTaskCommentMention>
{
    public void Configure(EntityTypeBuilder<MsgTaskCommentMention> b)
    {
        b.ToTable("msg_task_comment_mentions");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.CommentId, x.MentionedUserId }).IsUnique();
        b.WithTenantOrgBusFks();
        b.HasOne<MsgTaskComment>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "CommentId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.HasOne<MsgTaskStep>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "StepId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.HasOne<MsgTask>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "TaskId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.HasOne<User>().WithMany().HasForeignKey("MentionedUserId", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId)).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<User>().WithMany().HasForeignKey("CreatedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId)).OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class MsgTaskAttachmentConfiguration : IEntityTypeConfiguration<MsgTaskAttachment>
{
    public void Configure(EntityTypeBuilder<MsgTaskAttachment> b)
    {
        b.ToTable("msg_task_attachments");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.StepId });
        b.HasDeleteStatusCheck();
        b.WithTenantOrgBusFks();
        b.HasOne<MsgTaskStep>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "StepId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.HasOne<MsgTask>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "TaskId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.HasOne<MsgTaskComment>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "CommentId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.HasOne<MsgDocumentPath>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "DocumentId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.WithCrossSchemaAuditUserFks();
    }
}

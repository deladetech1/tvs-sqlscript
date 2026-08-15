using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.Common.Conventions;
using Trovesuite.Database.CorePlatform.Configurations;
using Trovesuite.Database.CorePlatform.Entities;
using Trovesuite.Database.MyStoreGuard.Entities;

namespace Trovesuite.Database.MyStoreGuard.Configurations;

public sealed class MsgMessageConfiguration : IEntityTypeConfiguration<MsgMessage>
{
    public void Configure(EntityTypeBuilder<MsgMessage> b)
    {
        b.ToTable("msg_messages");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Subject).HasColumnType("varchar(255)");
        b.Property(x => x.Channel).HasDefaultValue("SMS");
        b.Property(x => x.Status).HasDefaultValue("DRAFT");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz");
        b.HasInCheck("channel", "SMS", "EMAIL");
        b.HasInCheck("recipient_type", "SUPPLIER", "CUSTOMER");
        b.HasInCheck("status", "DRAFT", "SCHEDULED", "QUEUED", "SENDING", "SENT", "FAILED", "CANCELLED");
        b.WithTenantOrgBusFks();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class MsgMessageRecipientConfiguration : IEntityTypeConfiguration<MsgMessageRecipient>
{
    public void Configure(EntityTypeBuilder<MsgMessageRecipient> b)
    {
        b.ToTable("msg_message_recipients");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Status).HasDefaultValue("PENDING");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz");
        b.HasInCheck("recipient_type", "SUPPLIER", "CUSTOMER");
        b.HasInCheck("status", "PENDING", "SENT", "DELIVERED", "FAILED");
        b.WithTenantOrgBusFks();
        b.HasOne<MsgMessage>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "MessageId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        // created_by → cp_users RESTRICT
        b.HasOne<User>().WithMany().HasForeignKey("CreatedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId)).OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class MeetingConfiguration : IEntityTypeConfiguration<Meeting>
{
    public void Configure(EntityTypeBuilder<Meeting> b)
    {
        b.ToTable("msg_meetings");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.Title).HasColumnType("varchar(255)");
        b.Property(x => x.ReminderMinutes).HasDefaultValue(30);
        b.Property(x => x.ReminderChannel).HasDefaultValue("SMS");
        b.Property(x => x.Status).HasDefaultValue("SCHEDULED");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz");
        b.HasInCheck("participant_type", "SUPPLIER", "CUSTOMER");
        b.HasInCheck("reminder_channel", "SMS", "EMAIL");
        b.HasInCheck("status", "SCHEDULED", "REMINDER_SENT", "IN_PROGRESS", "COMPLETED", "CANCELLED");
        b.WithTenantOrgBusFks();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class MeetingParticipantConfiguration : IEntityTypeConfiguration<MeetingParticipant>
{
    public void Configure(EntityTypeBuilder<MeetingParticipant> b)
    {
        b.ToTable("msg_meeting_participants");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.RsvpStatus).HasDefaultValue("PENDING");
        b.Property(x => x.ReminderStatus).HasDefaultValue("PENDING");
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz");
        b.HasInCheck("participant_type", "SUPPLIER", "CUSTOMER");
        b.HasInCheck("rsvp_status", "PENDING", "ACCEPTED", "DECLINED");
        b.HasInCheck("reminder_status", "PENDING", "SENT", "DELIVERED", "FAILED");
        b.WithTenantOrgBusFks();
        b.HasOne<Meeting>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "MeetingId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "Id")
            .OnDelete(DeleteBehavior.Cascade);
        b.HasOne<User>().WithMany().HasForeignKey("CreatedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId)).OnDelete(DeleteBehavior.Restrict);
    }
}

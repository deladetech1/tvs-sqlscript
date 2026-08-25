using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.Common.Conventions;
using Trovesuite.Database.CorePlatform.Configurations;
using Trovesuite.Database.CorePlatform.Entities;
using Trovesuite.Database.MyStoreGuard.Entities;

namespace Trovesuite.Database.MyStoreGuard.Configurations;

public sealed class CollectionConfiguration : IEntityTypeConfiguration<Collection>
{
    public void Configure(EntityTypeBuilder<Collection> b)
    {
        b.ToTable("msg_collections");
        b.HasKey(x => new { x.TenantId, x.OrgId, x.BusId, x.LocId, x.Id });
        b.Property(x => x.Id).AsTextUuidDefault();

        b.Property(x => x.Amount).HasColumnType("numeric(18,2)");
        b.Property(x => x.Channel).HasDefaultValue("MOBILE_MONEY");
        b.Property(x => x.Status).HasDefaultValue("UNMATCHED");
        b.Property(x => x.MatchConfidence).HasDefaultValue(0);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("NOW()");

        b.HasInCheck("channel", "MOBILE_MONEY", "BANK_TRANSFER", "CASH_DEPOSIT");
        b.HasInCheck("status", "UNMATCHED", "MATCHED", "POSTED", "IGNORED");
        b.HasInCheck("match_method", "REFERENCE", "CONTACT", "AMOUNT_AND_DATE", "MANUAL");

        b.ToTable(t =>
        {
            t.HasCheckConstraint("ck_msg_collections_amount", "amount > 0");
            t.HasCheckConstraint("ck_msg_collections_confidence",
                "match_confidence >= 0 AND match_confidence <= 100");
            // Matched or posted means it points at a plan. Without this the
            // queue could show money as handled that landed nowhere.
            t.HasCheckConstraint("ck_msg_collections_matched_has_plan",
                "status NOT IN ('MATCHED','POSTED') OR plan_id IS NOT NULL");
            // Posted means it became a payment, and that payment is the proof.
            t.HasCheckConstraint("ck_msg_collections_posted_has_payment",
                "status <> 'POSTED' OR payment_id IS NOT NULL");
            // Ignoring somebody's money is a decision that needs a name on it.
            t.HasCheckConstraint("ck_msg_collections_ignored_has_reason",
                "status <> 'IGNORED' OR (resolved_by IS NOT NULL AND resolution_note IS NOT NULL)");
        });

        // The provider's reference is unique per business: importing the same
        // statement twice is the normal case, not the exception, and must not
        // double-post anybody's instalment.
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.ExternalReference })
            .IsUnique();
        // The queue reads by status, newest first.
        b.HasIndex(x => new { x.TenantId, x.OrgId, x.BusId, x.Status, x.PaidAt });

        b.WithTenantOrgBusLocFks();
        b.HasOne<InstallmentPlan>().WithMany()
            .HasForeignKey("TenantId", "OrgId", "BusId", "LocId", "PlanId")
            .HasPrincipalKey("TenantId", "OrgId", "BusId", "LocId", "Id")
            .OnDelete(DeleteBehavior.SetNull);
        b.WithCrossSchemaCreateUpdateUserFks();
        b.HasOne<User>().WithMany().HasForeignKey("ResolvedBy", "TenantId")
            .HasPrincipalKey(nameof(User.Id), nameof(User.TenantId))
            .OnDelete(DeleteBehavior.Restrict);
    }
}

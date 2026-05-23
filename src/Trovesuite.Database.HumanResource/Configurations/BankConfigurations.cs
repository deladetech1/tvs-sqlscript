using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Trovesuite.Database.Common.Conventions;
using Trovesuite.Database.CorePlatform.Configurations;
using Trovesuite.Database.HumanResource.Entities;

namespace Trovesuite.Database.HumanResource.Configurations;

public sealed class BankConfiguration : IEntityTypeConfiguration<Bank>
{
    public void Configure(EntityTypeBuilder<Bank> b)
    {
        b.ToTable("hr_banks");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("CURRENT_TIMESTAMP");
        b.HasIndex(x => new { x.TenantId, x.Name }).IsUnique();
        b.HasDeleteStatusCheck();

        b.WithTenantFk();
        b.WithCrossSchemaAuditUserFks();
    }
}

public sealed class BankBranchConfiguration : IEntityTypeConfiguration<BankBranch>
{
    public void Configure(EntityTypeBuilder<BankBranch> b)
    {
        b.ToTable("hr_bank_branches");
        b.HasKey(x => new { x.Id, x.TenantId });
        b.Property(x => x.Id).AsTextUuidDefault();
        b.Property(x => x.DeleteStatus).HasDefaultValue("NOT_DELETED");
        b.Property(x => x.IsActive).HasDefaultValue(true);
        b.Property(x => x.Cdatetime).HasColumnType("timestamptz").HasDefaultValueSql("CURRENT_TIMESTAMP");
        b.HasIndex(x => new { x.TenantId, x.BankId, x.Name }).IsUnique();
        b.HasDeleteStatusCheck();

        b.WithTenantFk();
        b.HasOne<Bank>().WithMany()
            .HasForeignKey("BankId", "TenantId")
            .HasPrincipalKey("Id", "TenantId").OnDelete(DeleteBehavior.Cascade);
        b.WithCrossSchemaAuditUserFks();
    }
}

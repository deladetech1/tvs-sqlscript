using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Trovesuite.Database.Common.Conventions;

public static class FluentExtensions
{
    /// <summary>
    /// Adds the standard delete_status CHECK constraint
    /// (PENDING / DELETED / NOT_DELETED).
    /// </summary>
    public static EntityTypeBuilder<T> HasDeleteStatusCheck<T>(this EntityTypeBuilder<T> b) where T : class
    {
        var table = b.Metadata.GetTableName();
        b.ToTable(t => t.HasCheckConstraint($"ck_{table}_delete_status",
            "delete_status IN ('PENDING','DELETED','NOT_DELETED')"));
        return b;
    }

    /// <summary>
    /// Add a CHECK constraint scoped to a single column with an IN(...) list.
    /// </summary>
    public static EntityTypeBuilder<T> HasInCheck<T>(this EntityTypeBuilder<T> b, string column, params string[] allowedValues) where T : class
    {
        var table = b.Metadata.GetTableName();
        var quoted = string.Join(",", allowedValues.Select(v => v is null ? "NULL" : $"'{v}'"));
        b.ToTable(t => t.HasCheckConstraint($"ck_{table}_{column}", $"{column} IN ({quoted})"));
        return b;
    }

    /// <summary>
    /// Maps the typical "text id with uuid default" primary key.
    /// </summary>
    public static PropertyBuilder<string> AsTextUuidDefault(this PropertyBuilder<string> p) =>
        p.HasColumnType("text").HasDefaultValueSql("gen_random_uuid()::text");

    /// <summary>
    /// Maps a timestamptz column that defaults to CURRENT_TIMESTAMP.
    /// </summary>
    public static PropertyBuilder<DateTimeOffset?> AsTimestampDefault(this PropertyBuilder<DateTimeOffset?> p) =>
        p.HasColumnType("timestamptz").HasDefaultValueSql("CURRENT_TIMESTAMP");
}

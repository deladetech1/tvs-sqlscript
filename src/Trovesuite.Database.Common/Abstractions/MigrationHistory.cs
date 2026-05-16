using Microsoft.EntityFrameworkCore;

namespace Trovesuite.Database.Common.Abstractions;

/// <summary>
/// Helpers for keeping <c>__EFMigrationsHistory</c> in sync with the bkup-SQL
/// bootstrap. When a fresh DB is deployed by running the verbatim bkup files,
/// the tables exist but EF doesn't know they came from a migration. Marking the
/// Initial migration as applied makes the next <c>MigrateAsync</c> a no-op.
/// </summary>
public static class MigrationHistory
{
    private const string EfCoreProductVersion = "10.0.1";

    /// <summary>
    /// Ensures <c>{schema}.__EFMigrationsHistory</c> exists and records the
    /// first migration (typically <c>YYYYMMDDhhmmss_Initial</c>) as applied.
    /// Idempotent: safe to call on a DB that already has the row.
    /// </summary>
    public static async Task MarkInitialAsAppliedAsync(
        DbContext context,
        string schemaName,
        CancellationToken cancellationToken = default)
    {
        var migrations = context.Database.GetMigrations().OrderBy(m => m, StringComparer.Ordinal).ToList();
        if (migrations.Count == 0) return;

        var initial = migrations[0];

        // EF's history table uses quoted PascalCase column names.
        await context.Database.ExecuteSqlRawAsync(
            $@"CREATE TABLE IF NOT EXISTS {schemaName}.""__EFMigrationsHistory"" (
                ""MigrationId"" character varying(150) NOT NULL,
                ""ProductVersion"" character varying(32) NOT NULL,
                CONSTRAINT ""PK___EFMigrationsHistory"" PRIMARY KEY (""MigrationId"")
            );",
            cancellationToken);

        // Values are assembly metadata (migration id) and a constant — safe to inline.
        await context.Database.ExecuteSqlRawAsync(
            $@"INSERT INTO {schemaName}.""__EFMigrationsHistory"" (""MigrationId"", ""ProductVersion"")
               VALUES ('{initial}', '{EfCoreProductVersion}')
               ON CONFLICT (""MigrationId"") DO NOTHING;",
            cancellationToken);
    }
}

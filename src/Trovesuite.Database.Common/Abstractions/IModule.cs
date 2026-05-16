using Microsoft.EntityFrameworkCore;

namespace Trovesuite.Database.Common.Abstractions;

/// <summary>
/// A deployable database module (matches a sub-directory under the legacy bkup/ layout).
/// </summary>
public interface IModule
{
    /// <summary>Deploy order: 1 = core_platform, 2 = loandrift, 3 = mystoreguard, 4 = hr.</summary>
    int Order { get; }

    /// <summary>Stable key used to identify the module in CLI prompts (e.g. "core_platform").</summary>
    string ModuleKey { get; }

    /// <summary>PG schema this module owns.</summary>
    string SchemaName { get; }

    /// <summary>Construct a DbContext for this module against the given connection string.</summary>
    DbContext CreateContext(string connectionString);

    /// <summary>
    /// Apply post-migration steps: triggers, seed data (resource types, permissions, roles).
    /// Idempotent — safe to re-run.
    /// </summary>
    Task SeedAsync(DbContext context, CancellationToken cancellationToken = default);
}

/// <summary>
/// Helpers for loading SQL embedded via &lt;EmbeddedResource Include="Sql\**\*.sql" /&gt;.
/// </summary>
public static class EmbeddedSql
{
    public static string Load(System.Reflection.Assembly assembly, string resourceSuffix)
    {
        var name = assembly.GetManifestResourceNames()
            .SingleOrDefault(n => n.EndsWith(resourceSuffix, StringComparison.OrdinalIgnoreCase))
            ?? throw new InvalidOperationException(
                $"Embedded SQL resource ending with '{resourceSuffix}' not found in {assembly.GetName().Name}.");

        using var stream = assembly.GetManifestResourceStream(name)!;
        using var reader = new StreamReader(stream);
        return reader.ReadToEnd();
    }

    public static IEnumerable<(string Name, string Body)> LoadAllOrdered(
        System.Reflection.Assembly assembly,
        string folderSuffix)
    {
        return assembly.GetManifestResourceNames()
            .Where(n => n.Contains($".{folderSuffix}.", StringComparison.OrdinalIgnoreCase)
                        && n.EndsWith(".sql", StringComparison.OrdinalIgnoreCase))
            .OrderBy(n => n, StringComparer.OrdinalIgnoreCase)
            .Select(n =>
            {
                using var stream = assembly.GetManifestResourceStream(n)!;
                using var reader = new StreamReader(stream);
                return (n, reader.ReadToEnd());
            });
    }
}

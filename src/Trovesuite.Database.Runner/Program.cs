using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql;
using Trovesuite.Database.Common.Abstractions;
using Trovesuite.Database.CorePlatform;
using Trovesuite.Database.HumanResource;
using Trovesuite.Database.LoanDrift;
using Trovesuite.Database.MyStoreGuard;

namespace Trovesuite.Database.Runner;

/// <summary>
/// Mirrors the behavior of script_db_setup.sh, but in C# / EF Core:
///   - Discovers modules (in 1..n order to honor cross-module FK dependencies)
///   - Prompts for the action (deploy/verify/rollback/status)
///   - For deploy/rollback prompts for which module(s) to target
///   - Executes EnsureCreated() + seed for each chosen module
///
/// Connection settings are pulled from these env vars (same as the legacy .env):
///   DB_HOST, DB_PORT, DB_USER, PGPASSWORD, DB_NAME
/// Command-line: tvs-db [DB_HOST DB_PORT DB_USER DB_PASSWORD DB_NAME] [deploy|verify|rollback|status]
/// </summary>
internal static class Program
{
    private static readonly IModule[] Modules =
    [
        new CorePlatformModule(),
        new LoanDriftModule(),
        new MyStoreGuardModule(),
        new HumanResourceModule(),
    ];

    private static int Main(string[] args)
    {
        try
        {
            return MainAsync(args).GetAwaiter().GetResult();
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"❌ {ex.Message}");
            if (Environment.GetEnvironmentVariable("TVS_DEBUG") == "1")
                Console.Error.WriteLine(ex);
            return 1;
        }
    }

    private static async Task<int> MainAsync(string[] args)
    {
        PrintHeader("🚀 Core Platform Deployment Script (EF Core 10)");

        var cfg = ReadConfig(args);
        var action = ReadAction(args, cfg);

        Info($"  Host: {cfg.Host}");
        Info($"  Port: {cfg.Port}");
        Info($"  User: {cfg.User}");
        Info($"  Database: {cfg.Database}");
        Console.WriteLine();

        IModule[] selected = action is "deploy" or "rollback"
            ? PromptModuleSelection()
            : Modules;

        switch (action)
        {
            case "deploy": await Deploy(cfg, selected); break;
            case "verify": await Verify(cfg); break;
            case "rollback": await Rollback(cfg, selected); break;
            case "status": await Status(cfg); break;
            case "validate": Validate(cfg); break;
            default: Error($"Invalid action: {action}"); return 1;
        }
        return 0;
    }

    /// <summary>
    /// Builds every module's EF model offline. Surfaces Fluent API errors
    /// (missing keys, FK type mismatches, bad CHECK constraints) without
    /// needing a database connection.
    /// </summary>
    private static void Validate(DbConfig cfg)
    {
        PrintHeader("Validating EF Core Models");
        foreach (var mod in Modules.OrderBy(m => m.Order))
        {
            using var ctx = mod.CreateContext(cfg.ToConnectionString());
            var entityCount = ctx.Model.GetEntityTypes().Count();
            Success($"{mod.ModuleKey}: model OK — {entityCount} entity types");
        }
    }

    // --------- migration helpers ---------

    /// <summary>
    /// Applies pending EF Core migrations, automatically reconciling history drift.
    /// If a migration fails because its target object already exists (any of the
    /// Postgres "duplicate object" SQLSTATEs — see <see cref="DuplicateObjectSqlStates"/>)
    /// — meaning the DDL was applied outside of EF Core's history tracking — the
    /// migration is recorded as applied in <c>__EFMigrationsHistory</c> and the loop
    /// retries. This baselines a DB whose schema was created by another tool (or whose
    /// history was reset) in a single pass.
    ///
    /// Caveat: a migration is reconciled as a whole — if it both touches an existing
    /// object AND introduces a genuinely-new one, the failed transaction rolls back and
    /// the migration is skipped entirely, so the new object is NOT created. This is safe
    /// when the DB is a full materialization of the model (the baseline case); after a
    /// reconciling deploy, run <c>command=migrations-list</c> and confirm the model and
    /// DB agree if the DB might only be partially materialized.
    /// </summary>
    private static async Task SafeMigrateAsync(DbContext ctx)
    {
        while (true)
        {
            var pending = (await ctx.Database.GetPendingMigrationsAsync()).ToList();
            if (pending.Count == 0) return;

            try
            {
                await ctx.Database.MigrateAsync();
                return;
            }
            catch (Exception ex) when (IsObjectAlreadyExists(ex))
            {
                // EF Core applies migrations in order and wraps each in its own
                // transaction; on failure the failed migration is rolled back and
                // the preceding ones are already committed and in history.
                // Re-query pending so we see exactly which migration failed.
                var stillPending = (await ctx.Database.GetPendingMigrationsAsync()).ToList();
                if (stillPending.Count == 0) return;  // Nothing left — shouldn't happen but be safe.

                var failingId = stillPending[0];
                Info($"  Reconciling: '{failingId}' already applied outside EF — recording in history.");

                // Let EF generate the history SQL via its own IHistoryRepository so the
                // table name, schema, columns, and naming convention (snake_case here)
                // always match what EF itself produced — never hand-write this SQL.
                var history = ctx.GetService<IHistoryRepository>();
                var productVersion = typeof(DbContext).Assembly.GetName().Version?.ToString() ?? "10.0.0";

#pragma warning disable EF1002
                await ctx.Database.ExecuteSqlRawAsync(history.GetCreateIfNotExistsScript());
                await ctx.Database.ExecuteSqlRawAsync(history.GetInsertScript(new HistoryRow(failingId, productVersion)));
#pragma warning restore EF1002
            }
        }
    }

    /// <summary>
    /// Postgres "duplicate object" SQLSTATEs — raised when a migration's DDL targets
    /// something that already exists because the schema was materialized outside EF.
    /// Catching the whole family (not just duplicate-table) lets one deploy baseline a
    /// pre-existing DB in a single pass instead of failing on each new error code.
    /// </summary>
    private static readonly HashSet<string> DuplicateObjectSqlStates = new()
    {
        "42P07", // duplicate_table (also index / sequence / view)
        "42701", // duplicate_column
        "42710", // duplicate_object (constraint, trigger, …)
        "42P06", // duplicate_schema
        "42723", // duplicate_function
    };

    private static bool IsObjectAlreadyExists(Exception ex)
    {
        for (var e = ex; e is not null; e = e.InnerException)
        {
            if (e is PostgresException pg && DuplicateObjectSqlStates.Contains(pg.SqlState))
                return true;
        }
        return false;
    }

    // --------- actions ---------

    private static async Task Deploy(DbConfig cfg, IModule[] selected)
    {
        PrintHeader("Deploying SQL Schema");
        await CheckConnection(cfg);

        foreach (var mod in selected.OrderBy(m => m.Order))
        {
            PrintHeader($"Deploying Module: {mod.ModuleKey}");
            await using var ctx = mod.CreateContext(cfg.ToConnectionString());

            Info($"  Ensuring schema '{mod.SchemaName}' exists…");
            await EnsureSchemaAsync(ctx, mod.SchemaName);

            Info("  Applying EF Core migrations…");
            await SafeMigrateAsync(ctx);

            Info("  Running module seed (triggers + reference data)…");
            await mod.SeedAsync(ctx);
            Success($"Module {mod.ModuleKey} deployed successfully");
        }

        // Custom post-migration SQL on top of EF Core migrations:
        //   migrations/shared/*.sql           — applied to every target
        //   migrations/enterprise/<slug>/*.sql — applied when TVS_ENTERPRISE is set
        await ApplyCustomMigrationSql(cfg);

        Success("All selected modules deployed successfully");
    }

    /// <summary>
    /// Runs <c>CREATE SCHEMA IF NOT EXISTS</c> for a module schema. The schema
    /// name comes from <see cref="IModule.SchemaName"/> (always a hard-coded
    /// const like <c>core_platform</c>) so it's safe to inline into DDL —
    /// schema identifiers can't be parameterized in Postgres. We validate
    /// against a strict allow-list as belt-and-braces against accidental
    /// future use with untrusted input.
    /// </summary>
    private static async Task EnsureSchemaAsync(DbContext ctx, string schemaName)
    {
        if (!System.Text.RegularExpressions.Regex.IsMatch(schemaName, "^[A-Za-z_][A-Za-z0-9_]{0,62}$"))
            throw new InvalidOperationException($"Refusing to CREATE SCHEMA with unsafe name: '{schemaName}'");

        // EF1002 fires because EF can't statically verify the interpolated
        // value. We just did (regex above), and identifiers can't be passed
        // as SQL parameters — so suppress the analyzer locally.
#pragma warning disable EF1002
        await ctx.Database.ExecuteSqlRawAsync($"CREATE SCHEMA IF NOT EXISTS {schemaName};");
#pragma warning restore EF1002
    }

    /// <summary>
    /// Applies the on-disk SQL under <c>migrations/shared/</c> and (optionally)
    /// <c>migrations/enterprise/&lt;slug&gt;/</c>. Order: shared first, then
    /// enterprise — both in lexicographic filename order. Every file is expected
    /// to be idempotent (CREATE … IF NOT EXISTS / ON CONFLICT DO NOTHING).
    /// </summary>
    private static async Task ApplyCustomMigrationSql(DbConfig cfg)
    {
        var migrationsRoot = ResolveMigrationsRoot();
        if (migrationsRoot is null)
        {
            Info("  No 'migrations/' folder found — skipping shared/enterprise SQL.");
            return;
        }

        var connectionString = cfg.ToConnectionString();
        await using var conn = new NpgsqlConnection(connectionString);
        await conn.OpenAsync();

        await RunSqlFolder(conn, Path.Combine(migrationsRoot, "shared"), label: "shared");

        var enterprise = Environment.GetEnvironmentVariable("TVS_ENTERPRISE");
        if (!string.IsNullOrWhiteSpace(enterprise))
        {
            var enterpriseFolder = Path.Combine(migrationsRoot, "enterprise", enterprise.Trim());
            if (Directory.Exists(enterpriseFolder))
            {
                await RunSqlFolder(conn, enterpriseFolder, label: $"enterprise/{enterprise}");
            }
            else
            {
                Info($"  TVS_ENTERPRISE='{enterprise}' set but '{enterpriseFolder}' doesn't exist — skipping.");
            }
        }
    }

    private static async Task RunSqlFolder(NpgsqlConnection conn, string folder, string label)
    {
        if (!Directory.Exists(folder)) return;

        var files = Directory.GetFiles(folder, "*.sql", SearchOption.TopDirectoryOnly)
            .OrderBy(f => Path.GetFileName(f), StringComparer.Ordinal)
            .ToArray();

        if (files.Length == 0) return;

        PrintHeader($"Custom SQL: {label} ({files.Length} file{(files.Length == 1 ? "" : "s")})");
        foreach (var file in files)
        {
            Info($"  Running {Path.GetFileName(file)}…");
            var sql = await File.ReadAllTextAsync(file);
            await using var cmd = new NpgsqlCommand(sql, conn);
            await cmd.ExecuteNonQueryAsync();
        }
        Success($"{label}: {files.Length} file(s) applied");
    }

    /// <summary>
    /// Find the <c>migrations/</c> folder relative to the running binary
    /// (walks up from <see cref="AppContext.BaseDirectory"/>) so the runner
    /// works both from `dotnet run` (bin/Debug/net10.0/…) and from
    /// `dotnet publish`-ed builds.
    /// </summary>
    private static string? ResolveMigrationsRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            var candidate = Path.Combine(dir.FullName, "migrations");
            if (Directory.Exists(candidate)) return candidate;
            dir = dir.Parent;
        }
        return null;
    }

    private static async Task Verify(DbConfig cfg)
    {
        PrintHeader("Verifying Deployment");
        await CheckConnection(cfg);
        await using var conn = new NpgsqlConnection(cfg.ToConnectionString());
        await conn.OpenAsync();

        await using var cmdV = new NpgsqlCommand("SELECT version()", conn);
        await using var cmdD = new NpgsqlCommand("SELECT current_database()", conn);
        Info($"Database version: {await cmdV.ExecuteScalarAsync()}");
        Info($"Current database: {await cmdD.ExecuteScalarAsync()}");
    }

    private static async Task Status(DbConfig cfg) => await Verify(cfg);

    private static async Task Rollback(DbConfig cfg, IModule[] selected)
    {
        PrintHeader("Rolling Back Deployment");

        // A module can own more than one schema — e.g. HumanResource owns both
        // `human_resource` (hr_*) and `zeloshr` (zhr_*). Dropping only
        // IModule.SchemaName leaves the extra schema(s) behind, so a later deploy
        // replays migrations against still-existing objects. Use each module's
        // declared OwnedSchemas, which lists exactly the schemas it created (and
        // excludes schemas it only references via FK, like core_platform).
        // Drop in reverse Order so app schemas go before core_platform.
        var plan = selected
            .OrderByDescending(m => m.Order)
            .Select(m => (Module: m, Schemas: m.OwnedSchemas.ToList()))
            .ToList();

        Console.WriteLine("This will drop the following schemas (CASCADE):");
        foreach (var (m, schemas) in plan)
            Info($"  - {m.ModuleKey} -> {string.Join(", ", schemas)}");

        Console.Write("Continue? (y/N): ");
        var resp = Console.ReadLine();
        if (!string.Equals(resp, "y", StringComparison.OrdinalIgnoreCase))
        {
            Info("Rollback cancelled");
            return;
        }

        await using var conn = new NpgsqlConnection(cfg.ToConnectionString());
        await conn.OpenAsync();
        foreach (var (mod, schemas) in plan)
        {
            foreach (var schema in schemas)
            {
                // Schema names come from IModule.OwnedSchemas (hard-coded consts),
                // but validate before inlining since identifiers can't be parameterized.
                if (!System.Text.RegularExpressions.Regex.IsMatch(schema, "^[A-Za-z_][A-Za-z0-9_]{0,62}$"))
                    throw new InvalidOperationException($"Refusing to DROP SCHEMA with unsafe name: '{schema}'");

                Info($"Dropping schema '{schema}' (module: {mod.ModuleKey})…");
                await using var cmd = new NpgsqlCommand($"DROP SCHEMA IF EXISTS {schema} CASCADE;", conn);
                await cmd.ExecuteNonQueryAsync();
            }
        }
        Success("Rollback completed");
    }

    // --------- prompts / config ---------

    private record DbConfig(string Host, string Port, string User, string Password, string Database)
    {
        public string ToConnectionString()
        {
            // SSL is OFF by default (works for local Postgres without TLS configured).
            // Opt in for managed Postgres / production:
            //   TVS_SSL=true                  → SSL Mode=Require
            //   TVS_SSL=<Disable|Allow|Prefer|Require|VerifyCA|VerifyFull>
            //                                  → SSL Mode=<value>
            var raw = Environment.GetEnvironmentVariable("TVS_SSL");
            string sslMode = raw switch
            {
                null or "" or "false" or "0" or "off" => "Disable",
                "true" or "1" or "on" => "Require",
                _ => raw
            };
            return $"Host={Host};Port={Port};Username={User};Password={Password};Database={Database};SSL Mode={sslMode};Trust Server Certificate=true";
        }
    }

    private static DbConfig ReadConfig(string[] args)
    {
        TryLoadDotEnv();

        // Positional args take precedence over env vars (same as script_db_setup.sh).
        string Get(int i, string env) =>
            args.Length > i ? args[i] : Environment.GetEnvironmentVariable(env) ?? string.Empty;

        var host = Get(0, "DB_HOST");
        var port = Get(1, "DB_PORT");
        var user = Get(2, "DB_USER");
        var pwd  = Get(3, "PGPASSWORD");
        var db   = Get(4, "DB_NAME");

        if (string.IsNullOrEmpty(host) || string.IsNullOrEmpty(port) ||
            string.IsNullOrEmpty(user) || string.IsNullOrEmpty(pwd)  ||
            string.IsNullOrEmpty(db))
        {
            Error("Missing required database configuration!");
            Console.WriteLine();
            Console.WriteLine("Provide credentials via:");
            Console.WriteLine("  1. A .env file with DB_HOST, DB_PORT, DB_USER, PGPASSWORD, DB_NAME");
            Console.WriteLine("  2. CLI: tvs-db <DB_HOST> <DB_PORT> <DB_USER> <DB_PASSWORD> <DB_NAME> [deploy|verify|rollback|status]");
            Environment.Exit(1);
        }

        return new DbConfig(host, port, user, pwd, db);
    }

    private static string ReadAction(string[] args, DbConfig _)
    {
        var fromArg = args.Length > 5 ? args[5] : Environment.GetEnvironmentVariable("ACTION");
        if (!string.IsNullOrWhiteSpace(fromArg)) return fromArg!.Trim().ToLowerInvariant();

        Info("No action specified. Available actions: deploy, verify, rollback, status");
        Console.Write("Enter action to perform: ");
        return (Console.ReadLine() ?? "").Trim().ToLowerInvariant();
    }

    private static IModule[] PromptModuleSelection()
    {
        PrintHeader("Module Selection");
        Console.WriteLine("Available options:");
        Console.WriteLine("  0) Execute ALL modules");
        for (var i = 0; i < Modules.Length; i++)
            Console.WriteLine($"  {i + 1}) {Modules[i].ModuleKey}");

        Console.WriteLine();
        Console.Write("Enter your choice (0 for all, or specific number): ");
        var choice = (Console.ReadLine() ?? "").Trim();

        if (choice == "0")
        {
            Success("Selected: ALL modules");
            return Modules;
        }
        if (int.TryParse(choice, out var n) && n >= 1 && n <= Modules.Length)
        {
            var picked = Modules[n - 1];
            Success($"Selected: {picked.ModuleKey}");
            return [picked];
        }
        Error($"Invalid selection: {choice}");
        Environment.Exit(1);
        return Array.Empty<IModule>();
    }

    private static async Task CheckConnection(DbConfig cfg)
    {
        Info("Checking database connection…");
        await using var conn = new NpgsqlConnection(cfg.ToConnectionString());
        await conn.OpenAsync();
        await using var cmd = new NpgsqlCommand("SELECT 1;", conn);
        await cmd.ExecuteScalarAsync();
        Success("Database connection successful");
    }

    private static void TryLoadDotEnv()
    {
        // Look for .env in the current working dir, mirroring script_db_setup.sh's behavior.
        var path = Path.Combine(Directory.GetCurrentDirectory(), ".env");
        if (!File.Exists(path)) return;

        Info("Loading environment variables from .env file…");
        foreach (var raw in File.ReadAllLines(path))
        {
            var line = raw.Trim();
            if (line.Length == 0 || line.StartsWith('#')) continue;
            var eq = line.IndexOf('=');
            if (eq <= 0) continue;
            var k = line[..eq].Trim();
            var v = line[(eq + 1)..].Trim().Trim('"').Trim('\'');
            if (Environment.GetEnvironmentVariable(k) is null)
                Environment.SetEnvironmentVariable(k, v);
        }
    }

    // --------- output helpers ---------

    private static void PrintHeader(string title)
    {
        var bar = new string('=', 78);
        Console.WriteLine();
        Console.WriteLine(bar);
        Console.WriteLine($"🚀 {title}");
        Console.WriteLine(bar);
        Console.WriteLine();
    }
    private static void Success(string msg) => Console.WriteLine($"✅ {msg}");
    private static void Info(string msg)    => Console.WriteLine($"ℹ️  {msg}");
    private static void Error(string msg)   => Console.Error.WriteLine($"❌ {msg}");
}

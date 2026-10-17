using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.Accounting.Migrations
{
    /// <inheritdoc />
    public partial class CustomFieldSortFunctionsGuarded : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Same results as the API's in-memory versions (AccountingDbFunctions.CfNumber/CfDate): a plain decimal
            // or YYYY-MM-DD date, anything else NULL. The format checks reject NaN, Infinity, 1_000 and 0x1A (which
            // ::numeric would accept) and keep most rows off the exception path.
            migrationBuilder.Sql("""
                CREATE OR REPLACE FUNCTION accounting.cf_number(doc jsonb, field text)
                RETURNS numeric LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE AS $fn$
                DECLARE v text := btrim(doc ->> field);
                BEGIN
                    IF v IS NULL OR v !~ '^[+-]?([0-9]+[.]?[0-9]*|[.][0-9]+)([eE][+-]?[0-9]+)?$' THEN
                        RETURN NULL;
                    END IF;
                    RETURN v::numeric;
                EXCEPTION WHEN others THEN
                    RETURN NULL;
                END;
                $fn$;

                CREATE OR REPLACE FUNCTION accounting.cf_date(doc jsonb, field text)
                RETURNS date LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE AS $fn$
                DECLARE v text := btrim(doc ->> field);
                BEGIN
                    IF v IS NULL OR v !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN
                        RETURN NULL;
                    END IF;
                    RETURN v::date; -- impossible dates (2026-02-30) raise and give NULL
                EXCEPTION WHEN others THEN
                    RETURN NULL;
                END;
                $fn$;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // The unguarded versions from CustomFieldSortFunctions stay valid; nothing to restore.
        }
    }
}

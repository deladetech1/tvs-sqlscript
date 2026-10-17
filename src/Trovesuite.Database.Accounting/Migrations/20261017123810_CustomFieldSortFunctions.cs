using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.Accounting.Migrations
{
    /// <inheritdoc />
    public partial class CustomFieldSortFunctions : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Sort keys for custom field values (stored as strings in custom_fields_json): a NUMBER or DATE value that
            // does not parse sorts like an unset one instead of failing the query (PROCESSING_RULES 1.1, 13.4).
            migrationBuilder.Sql("""
                CREATE OR REPLACE FUNCTION accounting.cf_number(doc jsonb, field text)
                RETURNS numeric LANGUAGE plpgsql IMMUTABLE AS $fn$
                BEGIN
                    RETURN btrim(doc ->> field)::numeric;
                EXCEPTION WHEN others THEN
                    RETURN NULL;
                END;
                $fn$;

                CREATE OR REPLACE FUNCTION accounting.cf_date(doc jsonb, field text)
                RETURNS date LANGUAGE plpgsql IMMUTABLE AS $fn$
                BEGIN
                    IF btrim(doc ->> field) !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN
                        RETURN NULL;
                    END IF;
                    RETURN btrim(doc ->> field)::date; -- impossible dates (2026-02-30) raise and give NULL
                EXCEPTION WHEN others THEN
                    RETURN NULL;
                END;
                $fn$;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                DROP FUNCTION IF EXISTS accounting.cf_number(jsonb, text);
                DROP FUNCTION IF EXISTS accounting.cf_date(jsonb, text);
                """);
        }
    }
}

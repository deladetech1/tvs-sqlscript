using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.Accounting.Migrations
{
    /// <summary>
    /// Who the business is comes from Core Platform. Accounting no longer writes its own copy of the business's
    /// name, legal name, country, address, email and phone (it reads cp_businesses / cp_organizations per request),
    /// so those acc_org_settings columns become nullable. They are kept so rows written before still read.
    /// </summary>
    /// <remarks>
    /// The model also maps acc_customers and acc_suppliers as VIEWS from here on: migrations/shared/20261019-37 turns
    /// them into views of core_platform.cp_parties (the business's shared customers and suppliers) with Accounting's
    /// own fields in acc_customer_settings / acc_supplier_settings, keeping the old tables as *_legacy. EF scaffolded
    /// that change as DropTable; those operations are removed here on purpose, so nothing in EF ever drops or alters
    /// the views or the legacy tables. Idempotent.
    /// </remarks>
    public partial class IdentityFromCorePlatform : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
ALTER TABLE accounting.acc_org_settings
    ALTER COLUMN trading_name DROP NOT NULL,
    ALTER COLUMN legal_name DROP NOT NULL,
    ALTER COLUMN country DROP NOT NULL,
    ALTER COLUMN address DROP NOT NULL,
    ALTER COLUMN email DROP NOT NULL,
    ALTER COLUMN phone DROP NOT NULL;
""");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
UPDATE accounting.acc_org_settings
   SET trading_name = coalesce(trading_name, ''), legal_name = coalesce(legal_name, ''), country = coalesce(country, ''),
       address = coalesce(address, ''), email = coalesce(email, ''), phone = coalesce(phone, '')
 WHERE trading_name IS NULL OR legal_name IS NULL OR country IS NULL OR address IS NULL OR email IS NULL OR phone IS NULL;
ALTER TABLE accounting.acc_org_settings
    ALTER COLUMN trading_name SET NOT NULL,
    ALTER COLUMN legal_name SET NOT NULL,
    ALTER COLUMN country SET NOT NULL,
    ALTER COLUMN address SET NOT NULL,
    ALTER COLUMN email SET NOT NULL,
    ALTER COLUMN phone SET NOT NULL;
""");
        }
    }
}

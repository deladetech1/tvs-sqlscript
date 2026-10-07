using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.HumanResource.Migrations
{
    /// <inheritdoc />
    public partial class AddZhrDocumentExpiryAndFileId : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateOnly>(
                name: "expires_on",
                schema: "zeloshr",
                table: "zhr_employee_documents",
                type: "date",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "file_document_id",
                schema: "zeloshr",
                table: "zhr_employee_documents",
                type: "character varying(128)",
                maxLength: 128,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "expires_on",
                schema: "zeloshr",
                table: "zhr_employee_documents");

            migrationBuilder.DropColumn(
                name: "file_document_id",
                schema: "zeloshr",
                table: "zhr_employee_documents");
        }
    }
}

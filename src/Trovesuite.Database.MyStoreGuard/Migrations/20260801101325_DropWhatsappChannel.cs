using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Trovesuite.Database.MyStoreGuard.Migrations
{
    /// <inheritdoc />
    public partial class DropWhatsappChannel : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_messages_channel",
                schema: "mystoreguard",
                table: "msg_messages");

            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_meetings_reminder_channel",
                schema: "mystoreguard",
                table: "msg_meetings");

            // WhatsApp was never rolled out; fall any leftover rows back to SMS
            // so the tightened constraints can be applied.
            migrationBuilder.Sql(
                "UPDATE mystoreguard.msg_messages SET channel = 'SMS' WHERE channel = 'WHATSAPP';");

            migrationBuilder.Sql(
                "UPDATE mystoreguard.msg_meetings SET reminder_channel = 'SMS' WHERE reminder_channel = 'WHATSAPP';");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_messages_channel",
                schema: "mystoreguard",
                table: "msg_messages",
                sql: "channel IN ('SMS','EMAIL')");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_meetings_reminder_channel",
                schema: "mystoreguard",
                table: "msg_meetings",
                sql: "reminder_channel IN ('SMS','EMAIL')");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_messages_channel",
                schema: "mystoreguard",
                table: "msg_messages");

            migrationBuilder.DropCheckConstraint(
                name: "ck_msg_meetings_reminder_channel",
                schema: "mystoreguard",
                table: "msg_meetings");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_messages_channel",
                schema: "mystoreguard",
                table: "msg_messages",
                sql: "channel IN ('SMS','EMAIL','WHATSAPP')");

            migrationBuilder.AddCheckConstraint(
                name: "ck_msg_meetings_reminder_channel",
                schema: "mystoreguard",
                table: "msg_meetings",
                sql: "reminder_channel IN ('SMS','EMAIL','WHATSAPP')");
        }
    }
}

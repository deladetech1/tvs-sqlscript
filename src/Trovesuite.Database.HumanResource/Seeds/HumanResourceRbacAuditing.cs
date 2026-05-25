namespace Trovesuite.Database.HumanResource.Seeds;

internal static class HumanResourceRbacAuditing
{
    public static (string Cdate, string Ctime, DateTimeOffset Cdatetime) Now()
    {
        var now = DateTimeOffset.UtcNow;
        return (now.ToString("yyyy-MM-dd"), now.ToString("HH:mm:ss"), now);
    }
}

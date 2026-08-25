namespace Trovesuite.Database.MyStoreGuard.Entities;

/// <summary>
/// Money that arrived without going through the till.
///
/// A customer pays their instalment by mobile money on a Sunday. It reaches
/// the shop's account, and nothing in the system knows: the plan still shows
/// them owing, the reminder job still chases them, and someone eventually
/// keys it in from a phone screenshot.
///
/// A collection is one line off a mobile-money or bank statement, imported or
/// entered by hand. The matcher tries to attach it to a plan; whatever it
/// cannot attach confidently waits in a queue for a person, rather than being
/// guessed at. Guessing here posts a stranger's money against somebody's debt.
/// </summary>
public class Collection
{
    public string Id { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string OrgId { get; set; } = default!;
    public string BusId { get; set; } = default!;
    public string LocId { get; set; } = default!;

    /// <summary>The provider's own reference, and the reason a re-import is harmless.</summary>
    public string ExternalReference { get; set; } = default!;
    /// <summary>MOBILE_MONEY, BANK_TRANSFER or CASH_DEPOSIT.</summary>
    public string Channel { get; set; } = "MOBILE_MONEY";
    public decimal Amount { get; set; }
    public string? Currency { get; set; }

    /// <summary>Whatever the statement said about who paid — often just a number.</summary>
    public string? PayerName { get; set; }
    public string? PayerContact { get; set; }
    /// <summary>The narration, which is where a customer usually types their sale number.</summary>
    public string? Narration { get; set; }
    public DateTimeOffset? PaidAt { get; set; }

    /// <summary>UNMATCHED, MATCHED, POSTED, IGNORED.</summary>
    public string Status { get; set; } = "UNMATCHED";
    /// <summary>How it was matched: REFERENCE, CONTACT, AMOUNT_AND_DATE or MANUAL.</summary>
    public string? MatchMethod { get; set; }
    /// <summary>0–100. Anything under the posting threshold waits for a person.</summary>
    public int MatchConfidence { get; set; }

    public string? PlanId { get; set; }
    /// <summary>The payment this became, once posted.</summary>
    public string? PaymentId { get; set; }

    public string? ResolvedBy { get; set; }
    public DateTimeOffset? ResolvedAt { get; set; }
    public string? ResolutionNote { get; set; }

    /// <summary>Which import brought it in, so a bad file can be traced.</summary>
    public string? ImportBatch { get; set; }

    public string? Cdate { get; set; }
    public string? Ctime { get; set; }
    public DateTimeOffset? Cdatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

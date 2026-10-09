import pathlib, psycopg2
dsn=open("/private/tmp/claude-501/-Users-debrah-Documents-work-trovesuite/74cddde3-df1e-44a3-b1b7-a15db03abc4c/scratchpad/mig.dsn").read().strip()
sql=pathlib.Path("/Users/debrah/Documents/work/trovesuite/general/tvs-sqlscript/migrations/shared/20261008-02-an-address-is-built-from-a-name.sql").read_text()
c=psycopg2.connect(dsn); c.autocommit=False; cur=c.cursor()
FAILS=[]
def check(label, ok, detail=""):
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + ("" if ok else f"\n        {detail}"))
    if not ok: FAILS.append(label)
def sp(n): cur.execute(f"SAVEPOINT {n}")
def rb(n): cur.execute(f"ROLLBACK TO SAVEPOINT {n}")
try:
    cur.execute(sql)
    # A silo with a real tenant, as it would be after setup.
    cur.execute("""INSERT INTO control_plane.ctl_tenant_routes_tenant
      (host,tenant_id,tier,cell_key,silo_key,db_name,db_server_fqdn,container_prefix,
       status,is_wildcard,route_kind,cdatetime,created_by)
      VALUES ('kofi.dev.trovesuite.com','tnt_real','SILO_SHARED','uksouth-dev','kofi',
              'silo-kofi-dev','tvs-shared-sql.postgres.database.azure.com','kofi',
              'ACTIVE',false,'TENANT',now(),'probe')""")

    sp("a")
    cur.execute("SELECT control_plane.move_tenant_host(%s,%s,%s,%s)",
                ("kofi.dev.trovesuite.com","obeng","tnt_real","operator"))
    cur.execute("""SELECT host,tenant_id,tier,cell_key,silo_key,db_name,db_server_fqdn,
                          container_prefix,status
                     FROM control_plane.ctl_tenant_routes
                    WHERE host IN ('kofi.dev.trovesuite.com','obeng.dev.trovesuite.com')
                    ORDER BY host""")
    rows=cur.fetchall()
    new=[r for r in rows if r[0].startswith("obeng")]
    old=[r for r in rows if r[0].startswith("kofi")]
    check("the new address exists", len(new)==1, str(rows))
    check("...carrying the same tenant, tier, cell, silo and database",
          new and new[0][1:7]==old[0][1:7], f"new={new}\n        old={old}")
    check("...and the storage prefix", new and new[0][7]==old[0][7])
    check("the OLD address is still ACTIVE -- nobody is cut off",
          old and old[0][8]=="ACTIVE", str(old))
    rb("a")

    for label, args, want in [
        ("moving to the address it already has is a no-op",
         ("kofi.dev.trovesuite.com","kofi","tnt_real"), None),
        ("another tenant's address cannot be taken",
         ("kofi.dev.trovesuite.com","obeng","tnt_someone_else"), "belongs to tenant"),
        ("a PLATFORM address cannot be moved",
         ("dev.trovesuite.com","obeng","tnt_real"), "belongs to the platform"),
        ("a reserved label is refused",
         ("kofi.dev.trovesuite.com","api","tnt_real"), "reserved"),
        ("a malformed label is refused",
         ("kofi.dev.trovesuite.com","Not A Label","tnt_real"), "not a usable"),
        ("an unknown host is refused",
         ("nope.dev.trovesuite.com","obeng","tnt_real"), "no route for host"),
    ]:
        sp("b")
        try:
            cur.execute("SELECT control_plane.move_tenant_host(%s,%s,%s,%s)", (*args,"op"))
            got=None
        except Exception as e:
            got=str(e).strip().splitlines()[0]
        if want is None:
            check(label, got is None, f"raised: {got}")
        else:
            check(label, got is not None and want in got, f"got: {got}")
        rb("b")

    # Taking the name of an address that already exists.
    sp("c")
    cur.execute("""INSERT INTO control_plane.ctl_tenant_routes_tenant
      (host,tenant_id,tier,cell_key,silo_key,db_name,db_server_fqdn,container_prefix,
       status,is_wildcard,route_kind,cdatetime,created_by)
      VALUES ('taken.dev.trovesuite.com','tnt_other','SILO_SHARED','uksouth-dev','taken',
              'silo-taken-dev','tvs-shared-sql.postgres.database.azure.com','taken',
              'ACTIVE',false,'TENANT',now(),'probe')""")
    try:
        cur.execute("SELECT control_plane.move_tenant_host(%s,%s,%s,%s)",
                    ("kofi.dev.trovesuite.com","taken","tnt_real","op"))
        check("a host somebody already holds is refused", False, "it was allowed")
    except psycopg2.errors.UniqueViolation:
        check("a host somebody already holds is refused", True)
    except Exception as e:
        check("a host somebody already holds is refused", False, str(e).splitlines()[0])
    rb("c")
finally:
    c.rollback(); c.close()
print()
print(f"BROKEN: {len(FAILS)}" if FAILS else "OK -- a client can be moved, and nothing else can")

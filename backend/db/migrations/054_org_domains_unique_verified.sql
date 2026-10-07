-- Domain verification used to be self-attested (Verify compared the caller's
-- token to the one Add had just returned), so every existing "verified" row is
-- unproven. Reset them all; orgs re-verify through the DNS TXT check.
UPDATE public.org_domains
   SET verified = false, verified_at = NULL, auto_join_enabled = false
 WHERE verified;

-- A domain can be proven by exactly one org.
CREATE UNIQUE INDEX org_domains_verified_domain_uniq
    ON public.org_domains (lower(domain))
    WHERE verified;

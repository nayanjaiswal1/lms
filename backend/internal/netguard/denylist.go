// Package netguard provides a shared SSRF (server-side request forgery)
// denylist check for any code path that dials a hostname/IP an admin (or
// eventually a less-trusted caller) supplied. It exists so the same rule set
// backs both a request-time URL validator and a dial-time re-check — the
// two need to agree, and a hostname's DNS answer can change between the two
// moments (TOCTOU / DNS rebinding), so both must consult the same function.
package netguard

import "net"

// awsIMDSv6 is AWS's IPv6 instance-metadata-service address. Other clouds'
// IPv4 metadata endpoints (GCP, Azure, DigitalOcean, Oracle, etc. all use
// 169.254.169.254) are already covered by the link-local check below; AWS's
// IPv6 endpoint sits outside fc00::/7 and fe80::/10, so it needs an explicit
// entry. Not attempting to enumerate every cloud's IPv6 metadata address —
// this covers the common case without overfitting to one provider.
var awsIMDSv6 = net.ParseIP("fd00:ec2::254")

// metadataV4 is the near-universal cloud-metadata address (AWS, GCP, Azure,
// DigitalOcean, Oracle, ...). Already caught by IsLinkLocalUnicast below
// since it falls in 169.254.0.0/16, but it's called out explicitly so the
// intent is documented and the case gets a dedicated test.
var metadataV4 = net.ParseIP("169.254.169.254")

// IsDenylisted reports whether ip must not be dialed by this app on behalf
// of an admin-configured outbound target: loopback, RFC1918 private space,
// RFC4193 IPv6 unique-local, link-local (including the cloud-metadata
// address), unspecified (0.0.0.0 / ::), and known cloud-metadata addresses.
//
// A nil IP (e.g. a DNS answer that failed to parse) is treated as denied —
// callers should never dial on a failed/empty resolution.
//
// net.IP's IsPrivate/IsLoopback/IsLinkLocalUnicast already unwrap
// IPv4-mapped IPv6 addresses via To4() internally, so a bypass attempt like
// ::ffff:169.254.169.254 is caught the same as its plain IPv4 form — see
// denylist_test.go.
func IsDenylisted(ip net.IP) bool {
	if ip == nil {
		return true
	}
	if ip.IsUnspecified() || ip.IsLoopback() || ip.IsPrivate() || ip.IsLinkLocalUnicast() || ip.IsLinkLocalMulticast() {
		return true
	}
	return ip.Equal(metadataV4) || ip.Equal(awsIMDSv6)
}

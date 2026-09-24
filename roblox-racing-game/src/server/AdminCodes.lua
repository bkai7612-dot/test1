-- Secret admin codes (server only, never replicated to clients).
--
-- Only the SHA-256 hash of each code is stored here, so the code itself
-- isn't in the source. Redeeming one gives: every car (including the level
-- 50 reward), level 50, and every customization option (VIP-only ones too).
--
-- `maxUses` is counted across ALL servers in a DataStore, so the code
-- stops working once that many different accounts have redeemed it.
-- To add a new code: pick a random string, hash it (e.g. `echo -n CODE |
-- sha256sum`) and add an entry with a new `id`.
return {
	STORE = "RedlineRush_AdminCodes_v1",
	Codes = {
		["87d0ba68c373b2252a8d0bd018f87d988e92c7d9ae4d1ce60d6634befdedfdaa"] = {
			id = "ADMIN_1",
			maxUses = 2,
		},
	},
}

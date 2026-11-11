ApocWallet = ApocWallet or {}
ApocWallet.Protocol = ApocWallet.Protocol or {
    MODULE = "ApocWallet",
    LOGIN = "LoadBalance",
    STATE = "BalanceState",
    POLL_MS = 5000,
    CLIENT_TIMEOUT_MS = 180000,
}
return ApocWallet.Protocol

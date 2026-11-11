ApocWallet = ApocWallet or {}
ApocWallet.Protocol = ApocWallet.Protocol or {
    MODULE = "ApocWallet",
    LOGIN = "LoadBalance",
    REFRESH = "RefreshBalance",
    STATE = "BalanceState",
    MIN_REFRESH_MS = 5000,
    CLIENT_TIMEOUT_MS = 180000,
}
return ApocWallet.Protocol

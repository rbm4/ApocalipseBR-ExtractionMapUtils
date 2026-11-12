require 'ApocWallet/Protocol'
if ApocWallet.MarketProtocol then return ApocWallet.MarketProtocol end
local P={PAGE_SIZE=6,MAX_POST=100,LISTING_LIFETIME=48*60*60*1000,SALE_TAX_PERCENT=10}
ApocWallet.MarketProtocol=P
function P.code(fullType)
    local n=0
    for i=1,#fullType do n=(n*31+fullType:byte(i))%100000 end
    return string.format('CARGA-%05d',n)
end
function P.sector(x,y,z)
    return string.format('S%03d-%03d-N%d',math.floor(x/100),math.floor(y/100),z)
end
function P.integer(n,lo,hi) return type(n)=='number' and n==n and n%1==0 and n>=lo and n<=hi end
function P.token(s) return type(s)=='string' and #s>0 and #s<=80 and s:match('^[%w_.:%-]+$')~=nil end
return P

$path = 'https://api.zonky.cz/'
$pathToken = 'oauth/token'
$pathWallet = 'users/me/wallet'
$pathStats = 'users/me/investments/statistics'
$pathPeople = 'users/me/investments?loan.status__in=%5B%22ACTIVE%22,%22SIGNED%22,%22COVERED%22,%22PAID%22,%22PAID_OFF%22,%22STOPPED%22%5D'
$pathLogout = 'users/me/logout'
$cred = Get-Credential

$contentLength = $cred.UserName.Length + $cred.GetNetworkCredential().Password.Length + 61
#prihlaseni
$header = @{
Accept = "application/json, text/plain, */*"
"Accept-Encoding" = "gzip, deflate, br"
"Accept-Language"	= "cs,en-US;q=0.7,en;q=0.3"
Authorization = "Basic d2ViOndlYg=="
#Connection = "keep-alive"
"Content-Length" = $contentLength
"Content-Type" = "application/x-www-form-urlencoded"
Host = "api.zonky.cz"
Origin = "https://app.zonky.cz"
Referer = "https://app.zonky.cz/"
"User-Agent" = "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:46.0) Gecko/20100101 Firefox/46.0"
}
$body = @{
    username=$cred.UserName
    password=$cred.GetNetworkCredential().Password
    grant_type='password'
	scope='SCOPE_APP_WEB'
}	

$req = Invoke-restmethod -Uri ($path + $pathToken) -Method POST -Headers $header -Body $body 
$ServicePoint = [System.Net.ServicePointManager]::FindServicePoint($path + $pathToken)
$ServicePoint.CloseConnectionGroup("") | Out-Null
###################################################################################################
#token do hlavicky
$header['Authorization'] = "Bearer " + $req.access_token

#penezenka
$wallet = Invoke-restmethod -Uri ($path + $pathWallet) -Headers $header
$ServicePoint = [System.Net.ServicePointManager]::FindServicePoint($path + $pathWallet)
$ServicePoint.CloseConnectionGroup("") | Out-Null

#statistiky
$stats = Invoke-restmethod -Uri ($path + $pathStats) -Headers $header
$ServicePoint = [System.Net.ServicePointManager]::FindServicePoint($path + $pathStats)
$ServicePoint.CloseConnectionGroup("") | Out-Null

#lide co jsem podporil
$header.Add("X-Size", $stats.overallOverview.investmentCount)
$people = Invoke-restmethod -Uri ($path + $pathPeople) -Headers $header
$ServicePoint = [System.Net.ServicePointManager]::FindServicePoint($path + $pathPeople)
$ServicePoint.CloseConnectionGroup("") | Out-Null

#odhlaseni
$logout = Invoke-restmethod -Uri ($path + $pathLogout) -Headers $header
###################################################################################################


foreach ($item in $people)
	{
		$item.rating = switch ($item.rating) {"AAAAA" {"A**"} "AAAA" {"A*"} "AAA" {"A++"} "AA" {"A+"} default {$item.rating}}
		$item.nextPaymentDate = $item.nextPaymentDate.split("T")[0]
	}

$riskPortfolio = @{}
	foreach ($rating in $stats.riskPortfolio)
	{
		$riskPortfolio.add($rating.rating, [math]::Round(($rating.totalAmount * 100)/$stats.overallOverview.totalInvestment))
	}

$paid = $stats.overallOverview.principalPaid + $stats.overallOverview.interestPaid
$data = @(
	"Investovano: " + $stats.overallOverview.totalInvestment + " Kc"
	"Pocet investic: " + $stats.overallOverview.investmentCount
	"Stav penezenky: " + $wallet.availableBalance + " Kc"
	"Ocekavany urok: " + $stats.expectedProfitability * 100 + "%"
	"Splaceno: " + $paid + " Kc"
	"Vydelano: " + $stats.overallOverview.netIncome + " Kc"
) | Out-GridView

$people | Select-Object @{N="Název";E={$_.loanName}}, @{N="Investováno";E={$_.amount}}, @{N="Přezdívka";E={$_.nickname}}, rating, @{N="Další platba";E={$_.nextPaymentDate}}, `
						@{N="Status";E={$_.paymentStatus}}, @{N="Doba splácení";E={$_.loanTermInMonth}}, @{N="Zaplacený úrok";E={$_.paidInterest}}, @{N="Úrok po splatnosti";E={$_.dueInterest}}, `
						@{N="Vrátilo se mi";E={$_.paidPrincipal}}, @{N="Po splatnosti";E={$_.duePrincipal}}, @{N="Očekávaný úrok";E={$_.expectedInterest}}, @{N="Aktuální doba splácení";E={$_.currentTerm}} | Out-GridView
						
$riskPortfolio | Out-GridView
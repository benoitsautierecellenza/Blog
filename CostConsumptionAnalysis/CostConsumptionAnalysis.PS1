Param(
    [Parameter(Mandatory=$True)]
    [ValidateNotnullorEmpty()]
    [String]$SubscriptionID    
)
[String]$APIversion = "2019-04-01-preview"
[String]$Scope = "subscriptions/$SubscriptionID"
function Get-AzCachedAccessToken()
{
    #
    # Get Current token for connected user
    # OK
    # https://www.codeisahighway.com/how-to-easily-and-silently-obtain-accesstoken-bearer-from-an-existing-azure-powershell-session/
    $ErrorActionPreference = 'Stop'
    if(-not (Get-Module Az.Accounts)) {
        Import-Module Az.Accounts
    }
    $azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    if(-not $azProfile.Accounts.Count) {
        Write-Error "Ensure you have logged in before calling this function."    
    }
    $currentAzureContext = Get-AzContext
    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azProfile)
    Write-Debug ("Getting access token for tenant" + $currentAzureContext.Tenant.TenantId)
    $token = $profileClient.AcquireAccessToken($currentAzureContext.Tenant.TenantId)
    $token.AccessToken
}
Function Get-AzureCost4Period(
    [Parameter(Mandatory=$True)]
    [ValidateNotnullorEmpty()]
    [String]$Scope,
    [Parameter(Mandatory=$True)]
    [ValidateNotnullorEmpty()]
    [DateTime]$StartDate
)
{
    #
    # Retrive Dayly costs for a given period of time (Startdate), a period (Month, annually, ...) and a scope (subscription, resource group)
    #
    [String]$uri =  "https://management.azure.com/$Scope/providers/Microsoft.CostManagement/query?api-version=$APIversion"
    $YearBegin = (Get-Date $StartDate).year
    $MonthBegin = (Get-date $StartDate).Month
    $Thisyear = (Get-date $StartDate).Year
    $Thismonth = (Get-date $StartDate).month
    $DaysInMonth = [DateTime]::DaysInMonth($Thisyear, $Thismonth)
    $body = @{
        "type"="Usage";
        "timeframe"="Custom";
        "timePeriod"= @{
            "from"="$($yearBegin)-$($monthBegin)-01T00:00:00+00:00";
            "to"="$($Thisyear)-$($Thismonth)-$($DaysInMonth)T23:59:59+00:00"
        };
        "dataSet"=@{
            "granularity"="Daily";
            "aggregation"=@{
                "totalCost"=@{
                    "name"="PreTaxCost";"function"="Sum"}
                };
                "sorting"=@(@{"direction"="ascending";"name"="UsageDate"})
        }
    }
    $Json = $body | convertto-json -Depth 100
    $results = Invoke-RestMethod $uri -Headers $headers -ContentType "application/json" -Body $Json -Method Post
    $PresentationTable = @()
    $CumulatedCost = 0
    ForEach ($Cost in $results.properties.rows) {
        #
        # Parse Each cost (aggredation per day)
        # OK
        $CostYear  = (($cost[1]).tostring()).Substring(0,4)
        $CostMonth = (($cost[1]).tostring()).Substring(4,2)
        $CostDay = (($cost[1]).tostring()).Substring(6,2)
        $CumulatedCost += $cost[0]
        [DateTime]$CostDate = Get-date -Day $CostDay -Month $CostMonth -Year $CostYear -Hour 0 -Minute 0 -Second 0 -Format "MM/dd/yyyy"
        $item = New-Object PSObject
        $item | Add-Member -Type NoteProperty -Name "UsageDate"  -Value $CostDate
        $item | Add-Member -Type NoteProperty -Name "Cost"  -Value $cost[0]
        $item | Add-Member -Type NoteProperty -Name "Currency"  -Value $cost[2]
        $item | Add-Member -Type NoteProperty -Name "CumulatedCost" -Value $CumulatedCost
        $PresentationTable += $Item 
    }
    Return $PresentationTable
}
#
# Script begin
#
$token =  Get-AzCachedAccessToken 
$headers = @{"authorization"="bearer $token"} 
#
# Get costs details for an Azure subscription for this month
#
Write-Output "[CostConcumptionAnalysis] - Processing Azure costs for the current month."
[DateTime]$DateThisMonth = (Get-date -Day 01 -Month (Get-date).month -Year (Get-date).Year)
$ResultsThisMonth = Get-AzureCost4Period -StartDate $DateThisMonth -Scope "subscriptions/$SubscriptionID" 
#
# Get costs details for an Azure subscription for the month before
#
Write-Output "[CostConcumptionAnalysis] - Processing Azure costs for the month before."
$BaseDate = (Get-date).AddMonths(-1)
[DateTime]$DateLastMonth = (Get-date -Day 01 -Month ($BaseDate).month -Year ($BaseDate).Year)
$ResultsLastMonth = Get-AzureCost4Period -StartDate $DateLastMonth -Scope "subscriptions/$SubscriptionID" 
#
# Create a view combining both information to track cost drifts (Will include costs up to this day only)
# OK
$CostPresentationTable = @()
For ($day= 0; $day -lt ($ResultsThisMonth.Count); $day++) {
    $item = New-Object PSObject
    $ThisDaydata = $ResultsThisMonth[$day]
    $SameDayLastMonthData = $ResultsLastMonth[$day]
    $item | Add-Member -Type NoteProperty -Name "UsageDate"  -Value (get-date ($ThisDaydata.USageDate) -f d)
    $item | Add-Member -Type NoteProperty -Name "ThisMonthCost"  -Value ("{0:n2}" -f $ThisDaydata.Cost)
    $item | Add-Member -Type NoteProperty -Name "LastMonthCost"  -Value ("{0:n2}" -f $SameDayLastMonthData.Cost)
    $item | Add-Member -Type NoteProperty -Name "LastMonthCumulatedCost"  -Value ("{0:n2}" -f $SameDayLastMonthData.CumulatedCost)    
    $item | Add-Member -Type NoteProperty -Name "ThisMonthCumulatedCost"  -Value ("{0:n2}" -f $ThisDaydata.CumulatedCost)    
    $item | Add-Member -Type NoteProperty -Name "CostDrift" -Value ("{0:n2}" -f ($ThisDaydata.CumulatedCost - $SameDayLastMonthData.CumulatedCost))
    $item | Add-Member -Type NoteProperty -Name "Currency" -Value $ThisDaydata.Currency
    $CostPresentationTable += $item 
}
$CostPresentationTable | Format-Table -AutoSize
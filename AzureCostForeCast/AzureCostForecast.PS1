Param(
    [Parameter(Mandatory=$False)]
    [ValidateNotnullorEmpty()]
    $SubscriptionGUID 
)
[String]$SubscriptionLevelBudgetName = "SubscriptionLevel"
function Get-AzCachedAccessToken()
{
    #
    # Get Current token for connected user
    #
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
$token =  Get-AzCachedAccessToken 
$headers = @{"authorization"="bearer $token"} 
#
# Calcul du Forecast de consommation
#
Set-AzContext -SubscriptionId $SubscriptionGUID
#
# Version filtrée sur des dates
#
# Calculer une Begin date
# Calculer une date de fin en tenant compte du nombre de jours dans le mois (si budget au mois sinon voir le niveau de filtrage)
# $budget.TimeGrain Monthly,  quarterly, or annually.
$budget = Get-AzConsumptionBudget -Name $SubscriptionLevelBudgetName
[DateTime]$ExtractDate=($budget.TimePeriod.StartDate)
$BeginDay = $ExtractDate.Day
$BeginMonth = (get-date).month
$BeginYear = (Get-Date).Year
[DateTime]$StartDate = Get-date -Year $BeginYear -Month (get-date).month -Day $ExtractDate.Day
Switch ($budget.TimeGrain)
{
    "monthly"
    {
        [DateTime]$Enddate = $StartDate.AddMonths(1)
    }
    "Quarterly"
    {
        # Quarterly pour tester
        [DateTime]$Enddate = $StartDate.AddMonths(3)
    }
    "Annually"
    {
        # Annual pour tester
        [DateTime]$Enddate = $StartDate.AddMonths(12)

    }
}
$uri = "https://management.azure.com/subscriptions/$SubscriptionGUID/providers/Microsoft.Consumption/forecasts?$filter=usagedate ge '$StartDate' AND usagedate le '$EndDate'&api-version=2019-01-01"
$results = Invoke-RestMethod $uri -Headers $headers -ContentType "application/json" -Method Get
$PresentationTable = @()
$CumulatedCost = 0
Foreach ($Forecast in $Results.Value)
{
    $CumulatedCost += $Forecast.properties.Charge
    $item = New-Object PSObject
    $item | Add-Member -Type NoteProperty -Name "UsageDate"  -Value $Forecast.properties.usageDate
    $item | Add-Member -Type NoteProperty -Name "Grain"  -Value $Forecast.properties.grain
    $item | Add-Member -Type NoteProperty -Name "ChargeType"  -Value $Forecast.properties.ChargeType
    $item | Add-Member -Type NoteProperty -Name "Charge"  -Value $Forecast.properties.Charge
    $item | Add-Member -Type NoteProperty -Name "Currency"  -Value $Forecast.properties.Currency
    Switch ($Forecast.properties.chargeType)
    {
        "ForeCast"
        {
            $UpperBound = $Forecast.properties.confidenceLevels | Where-Object {$_.Bound -eq "Upper"}
            $item | Add-Member -Type NoteProperty -Name "UpperPercentage"  -Value $UpperBound.Percentage
            $item | Add-Member -Type NoteProperty -Name "UpperValue"  -Value $UpperBound.Value
            $LowerBound = $Forecast.properties.confidenceLevels | Where-Object {$_.Bound -eq "Lower"}
            $item | Add-Member -Type NoteProperty -Name "LowerPercentage"  -Value $LowerBound.Percentage
            $item | Add-Member -Type NoteProperty -Name "LowerValue"  -Value $LowerBound.Value        
        }
        "Actual"
        {
            $item | Add-Member -Type NoteProperty -Name "UpperPercentage"  -Value "N/A"
            $item | Add-Member -Type NoteProperty -Name "UpperValue"  -Value "N/A"
            $item | Add-Member -Type NoteProperty -Name "LowerPercentage"  -Value "N/A"
            $item | Add-Member -Type NoteProperty -Name "LowerValue"  -Value "N/A"
        }
    }
    $PresentationTable += $Item
}
$PresentationTable | Sort-Object UsageDate | format-table -AutoSize 
If ($CumulatedCost -Gt $Budget.Amount)
{
    Write-Warning "Forecasting Overbudget"
}
else {
    Write-host -ForegroundColor Green "Budget is Good"    
}

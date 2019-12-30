#
# Demo Custom Metrics
# Auteur : Benoît SAUTIERE
# Version 1.0
#
$VerbosePreference = 'SilentlyContinue'
[String]$AzureADTenantID = "<Azure AD Tenant ID>"
[String]$LogAnalyticsWorkspaceResourceID  = "/subscriptions/<SubscriptionID>/resourcegroups/<Resource Group>/providers/microsoft.operationalinsights/workspaces/<Log Analytic instance name>"
[String]$CustomMetricNameSpace = "Demo Custom Metric"
[String]$DimensionName = "DeQueued messages"
[String]$CustomMetricName = "Azure Firewall Processed messages"
[String]$ApplicationID = "<Azure AD Application ID>"
[String]$Secret = "Azure AD Application Secret"

Function Send-CustomMetric(
    [Parameter(Mandatory = $False)]
    [String]$TenantID, 

    [Parameter(Mandatory = $False)]
    [String]$AzureRegion,

    [Parameter(Mandatory = $False)]
    [String]$metricResourceID,

    [Parameter(Mandatory = $False)]
    [String]$CustomMetricName,

    [Parameter(Mandatory = $False)]
    [String]$DimensionName,    

    [Parameter(Mandatory = $False)]
    [String]$DimensionValue,    

    [Parameter(Mandatory = $False)]
    [Int]$MetricValueDimension
) {
    #
    # Seach Azure Monitor Custom Metric API (Based on Azure Region)
    #
    Switch ($AzureRegion) {
        "northeurope" {
            [String]$CustomMetricAPIURI = "https://northeurope.monitoring.azure.com"
        }
        "westeurope" {
            [String]$CustomMetricAPIURI = "https://westeurope.monitoring.azure.com"
        }
        "uksouth" {
            [String]$CustomMetricAPIURI = "https://uksouth.monitoring.azure.com"
        }
        "francecentral" {
            [String]$CustomMetricAPIURI = "https://francecentral.monitoring.azure.com"
        }
        "southafricanorth" {
            [String]$CustomMetricAPIURI = "https://southafricanorth.monitoring.azure.com"
        }
        "centralindia" {
            [String]$CustomMetricAPIURI = "https://centralindia.monitoring.azure.com"
        }
        "australiaeast" {
            [String]$CustomMetricAPIURI = "https://australiaeast.monitoring.azure.com"
        }
        "japanwest" {
            [String]$CustomMetricAPIURI = "https://japanwest.monitoring.azure.com"
        }
        "southeastasia" {
            [String]$CustomMetricAPIURI = "https://southeastasia.monitoring.azure.com"
        }
        "eastasia" {
            [String]$CustomMetricAPIURI = "https://eastasia.monitoring.azure.com"
        }
        "koreacentral" {
            [String]$CustomMetricAPIURI = "https://koreacentral.monitoring.azure.com"
        }
        "canadacentral" {
            [String]$CustomMetricAPIURI = "https://canadacentral.monitoring.azure.com"
        }
        "eastus" {
            [String]$CustomMetricAPIURI = "https://eastus.monitoring.azure.com"
        }
        "centralus" {
            [String]$CustomMetricAPIURI = "https://centralus.monitoring.azure.com"
        }
        "northcentralus" {
            [String]$CustomMetricAPIURI = "https://northcentralus.monitoring.azure.com"
        }
        "southcentralus" {
            [String]$CustomMetricAPIURI = "https://southcentralus.monitoring.azure.com"
        }
        "westus2" {
            [String]$CustomMetricAPIURI = "https://westus2.monitoring.azure.com"
        }
        "westcentralus" {
            [String]$CustomMetricAPIURI = "https://westcentralus.monitoring.azure.com"
        }
        Default {
            [String]$ErrorMessage = "[Send-CustomMetric] - Azure Region $AzureRegion not supported for Azure Monitor Custom metrics."
            Write-Verbose -Message $ErrorMessage -Verbose
            Write-Error $ErrorMessage
            Throw $ErrorMessage
            Return $False
        }
    }
    #
    # Get Oauth2 Token for Monitoring.Azure.com
    #
    [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
    $loginURL = "https://login.microsoftonline.com"
    $resource = "https://monitoring.azure.com/"
    $clientID = $Credential.UserName # ApplicationID
    $clientSecret = $Credential.GetNetworkCredential().password # Secret (To be replaced by Certificate)
    $body = @{grant_type = "client_credentials"; resource = $resource; client_id = $clientID; client_secret = $clientSecret }
    try {
        [String]$Message = "[Send-CustomMetric] - Negociating Oauth2 Token for resource $resource."
        Write-Verbose -Message $Message -Verbose
        $oauth = Invoke-RestMethod -Method Post -Uri $loginURL/$tenantID/oauth2/token?api-version=1.0 -Body $body    
        [String]$Message = "[Send-CustomMetric] - Got Oauth2 Token for resource $Resource."
        Write-Verbose -Message $Message -Verbose
    }
    catch {
        [String]$ErrorMessage = "[Send-CustomMetric] - Unable to get an Oauth2 Access token for resource $Resource. Error : $($_.Exception.Message)." 
        Write-Verbose -Message $ErrorMessage -Verbose
        Write-Error $ErrorMessage
        return $False
    }
    #
    # Build custom Metric PayLoad
    #
    $customMetric = @"
    {
        "time": "$([DateTime]::UTCNow.ToString('s'))",
        "data": {
            "baseData": {
            "metric": "$CustomMetricName",
            "namespace": "$CustomMetricNameSpace",
            "dimNames": [
                "$DimensionName"
            ],
            "series": [
            {
                "dimValues": [
                    "$DimensionValue"
                ],
                "min": $MetricValueDimension,
                "max": $MetricValueDimension,
                "sum": $MetricValueDimension,
                "count": 1
            }
        ]
        }
    }
}
"@
    #
    # Build Headers with Authorization parameter
    #
    $Headers = @{
        'Authorization' = "$($oauth.token_type) $($oauth.access_token)"
    }
    $metricAPIUri = $CustomMetricAPIURI + "$metricResourceID/metrics" # Car le MetricResourceID commence par un /
    # Fonctionnerea en Powershell 6 mais pas en 5 ;)
    try {
        [String]$Message = "[Send-CustomMetric] - Sending Custom Metric."
        Write-Verbose -Message $Message -Verbose
        Invoke-RestMethod -Method Post -Uri $metricAPIUri -Body $customMetric -Headers $Headers -ContentType 'application/json'    
        [String]$Message = "[Send-CustomMetric] - Custom Metric sent successfully."
        Write-Verbose -Message $Message -Verbose
        return $true
    }
    catch {
        [String]$ErrorMessage = "[Send-CustomMetric] - Failed to send Custom metric. Error : $($_.Exception.Message)." 
        Write-Verbose -Message $ErrorMessage -Verbose
        Write-Error $ErrorMessage
        return $False
    }    
}
#
# Service Principal authentication (Revoir pour méthode certificat)
#
$User = $ApplicationID
$PWord = ConvertTo-SecureString -String $Secret -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
Connect-AzAccount -Credential $Credential -Tenant $AzureADTenantID -ServicePrincipal | Out-Null

for($Count=1; $Count -le 10; $Count++)
{
    $AzureLocation = Get-Azlocation | Where-Object {$_.location -eq "WestEurope"}
    $Value = (get-random -minimum 0 -maximum 50)
    Send-CustomMetric -TenantID $AzureADTenantID `
        -AzureRegion "WestEurope" `
        -metricResourceID $LogAnalyticsWorkspaceResourceID `
        -CustomMetricName $CustomMetricName `
        -DimensionName $DimensionName `
        -MetricValueDimension  $Value `
        -DimensionValue "$($AzureLocation.DisplayName)"
    
    $AzureLocation = Get-Azlocation | Where-Object {$_.location -eq "NorthEurope"}    
    $Value = (get-random -minimum 0 -maximum 50)
    Send-CustomMetric -TenantID $AzureADTenantID `
        -AzureRegion "WestEurope" `
        -metricResourceID $LogAnalyticsWorkspaceResourceID `
        -CustomMetricName $CustomMetricName `
        -DimensionName $DimensionName `
        -MetricValueDimension  $Value `
        -DimensionValue "$($AzureLocation.DisplayName)"
    Start-Sleep -Seconds 60
}
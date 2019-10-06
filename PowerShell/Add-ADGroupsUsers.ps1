param(
    [Parameter(Mandatory)]
    [string]
    $Path
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

Import-Module -Name:"$PSScriptRoot\AzureSQL" -Force -ArgumentList:@(
    $ErrorActionPreference,
    $InformationPreference,
    $VerbosePreference
)

$Location = "uksouth"
$Identity = "$($Parameters.Tenant)-$($Parameters.Name)"
[string]$StorageAccountName = ConvertTo-StorageAccountName -Name:$Identity
$SQLDatabase = "$($Parameters.SQLDatabase.DatabaseName)"
$SQLGeneralUserGroup = "$($Parameters.SQLDatabase.SQLDBAccessGroup)"
Write-Information -MessageData:"Log into the Azure Tenancy"
az login
az account set --subscription "$($Parameters.AzureSubscription)"
az configure --defaults location=$Location

#Create a Storage Account
Write-Information -MessageData:"Creating the $StorageAccountName storage account."
az storage account create --resource-group $Identity --name $StorageAccountName --access-tier "Cool" --sku "Standard_LRS" --kind "StorageV2" --https-only $true | Out-Null

#Create Function App
Write-Information -MessageData:"Creating the $Identity function app"
az functionapp create --name $Identity --resource-group $Identity --consumption-plan-location $Location --storage-account $StorageAccountName --runtime "dotnet" | Out-Null

#Get the Function App Azure AD Identity
Write-Information -MessageData:"Assigning the $Identity function app identity."
$identityJson = az webapp identity assign --name $Identity --resource-group $Identity | ForEach-Object { $PSItem -join '' } | ConvertFrom-Json

#Create SQL General Users AD Group
$sqlAccessGroup = az ad group list --display-name $SQLGeneralUserGroup | ForEach-Object { $PSItem -join '' } | ConvertFrom-Json | Select-Object -First 1
if (-not $SQLAccessGroup) {
    Write-Information -MessageData:"Creating the $($SQLGeneralUserGroup) group."
    $sqlAccessGroup = az ad group create --display-name $SQLGeneralUserGroup --mail-nickname $SQLGeneralUserGroup | ForEach-Object { $PSItem -join '' } | ConvertFrom-Json
}

#Add Function App Identity to AD Group.
$memberExistsInGroup = az ad group member check --group "$($SqlAccessGroup.objectId)" --member-id "$($identityJson.principalId)" | ForEach-Object { $PSItem -join '' } | ConvertFrom-Json
if (-not $memberExistsInGroup.value) {
    Write-Information -MessageData:"Adding Member the $($Identity) to group $($SqlAccessGroup.displayName)."
    az ad group member add --group "$($SqlAccessGroup.objectId)" --member-id "$($identityJson.principalId)" | Out-Null
} 

#This has to be done with an actual AD account get current user token, current user is in the Admin Group.
$SPNADToken = az account get-access-token --resource https://database.windows.net/ | ForEach-Object { $PSItem -join '' } | ConvertFrom-Json

Write-Information -Message:"Setting the $SQLDatabase AD Group access."
#Update Query to the name of the AD Group.
$Query = [string]$(Get-Content -Path:"$PSScriptRoot\..\SQL\GiveAccess.sql" -Raw)  
$Query = $Query -replace '<UserName>', $SQLGeneralUserGroup

#Run Script
Invoke-SQLQuery -Server:"$($Identity.ToLower()).database.windows.net" -DatabaseName:$SQLDatabase -Query:$Query -AADToken:$($SPNADToken.accessToken)

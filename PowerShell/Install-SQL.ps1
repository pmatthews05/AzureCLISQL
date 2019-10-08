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
 

$Parameters = Get-Content -Raw -Path $Path | ConvertFrom-Json
$Identity = "$($Parameters.Tenant)-$($Parameters.Name)"
$SQLAdminUser = "$($Parameters.Tenant)-$($Parameters.SQLDatabase.AdminUser)"
$SQLAdminPassword = "$($Parameters.SQLDatabase.Password)"
$SQLDatabase = "$($Parameters.SQLDatabase.DatabaseName)"
$SQLAdminAppPrincipalName = "$($Parameters.SQLDatabase.SQLAdminAppPrincipalName)"
$SQLAdminADGroup = "$($Parameters.SQLDatabase.SQLAdminADGroup)"
$SQLGeneralUserGroup = "$($Parameters.SQLDatabase.SQLDBAccessGroup)"
$location = "uksouth"
Write-Information -MessageData:"Log into the Azure Tenancy"
az login
az account set --subscription "$($Parameters.AzureSubscription)"
az configure --defaults location=$location

Write-Information -MessageData:"Creating the $Identity resource group."
az group create --name $Identity | Out-Null

#SQL Admin User Principal Account
Write-Information -MessageData:"Getting the $SQLAdminAppPrincipalName Service Principal registration."
$SqlSPRegistration = az ad sp list --all --query "[?displayName == '$SQLAdminAppPrincipalName']" | ForEach-Object { $PSItem -join '' } | ConvertFrom-Json | Select-Object -First 1
if (-not $SqlSPRegistration) {
    Write-Information -MessageData:"Creating the $SQLAdminAppPrincipalName SP Registration."
    az ad sp create-for-rbac --name "http://$SQLAdminAppPrincipalName" --skip-assignment | Out-Null
    $SqlSPRegistration = az ad sp list --all --query "[?displayName == '$SQLAdminAppPrincipalName']" | ForEach-Object { $PSItem -join '' } | ConvertFrom-Json | Select-Object -First 1
}

#Create a password for SQL Principal.
Write-Information -MessageData:"Setting the $SQLAdminAppPrincipalName SP registration client secret."
$SQLAppPassword = [System.Web.Security.Membership]::GeneratePassword(25,5)
$ConvertedSPPassword = ConvertTo-EscapedString -String:$SQLAppPassword
$SqlAppPermission = az ad sp credential reset --name $SqlSPRegistration.AppId --password "$ConvertedSPPassword" --end-date '2299-12-31T00:00:00' | ForEach-Object { $PSItem -join '' } | ConvertFrom-Json


#Can only assign AZ AD Groups, by being logged in as a AD User Admin
#Create Admin AD Group
$SQLAccessAdminGroup = az ad group list --display-name $SQLAdminADGroup | ForEach-Object { $PSItem -join '' } | ConvertFrom-Json | Select-Object -First 1
   
if (-not $SQLAccessAdminGroup) {
    Write-Information -MessageData:"Creating the $SQLAdminADGroup group."
    $SQLAccessAdminGroup = az ad group create --display-name $SQLAdminADGroup --mail-nickname $SQLAdminADGroup | ForEach-Object { $PSItem -join '' } | ConvertFrom-Json
}

#Add current user to the Admin Group
$currentUser = az ad signed-in-user show | ForEach-Object { $PSItem -join '' } | ConvertFrom-Json
$currentmemberExistsInGroup = az ad group member check --group "$($SQLAccessAdminGroup.objectId)" --member-id "$($currentUser.objectId)" | ForEach-Object { $PSItem -join '' } | ConvertFrom-Json
if (-not $currentmemberExistsInGroup.value) {
    Write-Information -MessageData:"Adding Member the $($currentUser.displayName) to group $($SQLAccessAdminGroup.displayName)."
    az ad group member add --group "$($SQLAccessAdminGroup.objectId)" --member-id "$($currentUser.objectId)" | Out-Null
}

#Add SQL Admin User Principal Account to AD Admin Group
$memberExistsInGroup = az ad group member check --group "$($SQLAccessAdminGroup.objectId)" --member-id "$($SqlSPRegistration.objectId)" | ForEach-Object { $PSItem -join '' } | ConvertFrom-Json
if (-not $memberExistsInGroup.value) {
    Write-Information -MessageData:"Adding Member the $($SqlSPRegistration.appDisplayName) to group $($SQLAccessAdminGroup.displayName)."
    az ad group member add --group "$($SQLAccessAdminGroup.objectId)" --member-id "$($SqlSPRegistration.objectId)" | Out-Null
}

#Create SQL Server
Write-Information -MessageData:"Configure the $identity sql server"
az sql server create --name $($identity).ToLower() --resource-group $identity --admin-user $SQLAdminUser --admin-password "$(ConvertTo-EscapedString -String:$SQLAdminPassword)" | Out-Null

#Get Client IP address
Write-Information -MessageData:"Getting the deployment client external ip address."

try {
    $ipAddress = (Invoke-WebRequest 'http://myexternalip.com/raw' -TimeoutSec:10).Content -replace "`n"
}
catch {
    $Exception = $PSItem
    write-error -Message:$Exception
}

#Set Firewall rules - Current Clinet and All Azure.
Write-Information -MessageData:"Setting the development client sql server firewall rules."
az sql server firewall-rule create --end-ip-address $ipAddress --name 'deployment-client' --resource-group $Identity --server $($Identity).ToLower() --start-ip-address $ipAddress | Out-Null
Write-Information -MessageData:"Setting the allow all windows azure ips sql server firewall rules."
az sql server firewall-rule create --end-ip-address "0.0.0.0" --name 'AllowAllWindowsAzureIps' --resource-group $Identity --server $($Identity).ToLower()--start-ip-address "0.0.0.0" | Out-Null

#Create SQL Database
Write-Information -MessageData:"Setting the $SQLDatabase sql database."
az sql db create --resource-group $Identity --server $($Identity).ToLower() --name $SQLDatabase --service-objective GP_S_Gen5_1 | Out-Null 
#Set the AD Admin group as SQL Admin
Write-Information -MessageData:"Setting the AD Admin group: $SQLAdminADGroup as SQL Admin"
az sql server ad-admin create --resource-group $Identity --server-name $($Identity).ToLower() --display-name SQLAdmin --object-id $($SQLAccessAdminGroup.objectId) | Out-Null

#Connect as Service Principal
Write-Information -MessageData:"Getting Token for Service Principal to log in"
$subscription = az account show | ForEach-Object { $PSItem -join '' } | ConvertFrom-Json
$SPNToken = Get-AADToken -TenantID $subscription.tenantId -ServicePrincipalId $SqlSPRegistration.appId -ServicePrincipalPwd "$(ConvertTo-EscapedString -String:$SQLAppPassword)" -resourceAppIdURI "https://database.windows.net/"

#Run Script
$Query = [string]$(Get-Content -Path:"$PSScriptRoot\..\SQL\CreateEnvironment.sql" -Raw)
Invoke-SQLQuery -Server:"$($Identity.ToLower()).database.windows.net" -Database:$SQLDatabase -Query:$Query -AADToken:$SPNToken

#Get Storage Account Name
$StorageAccountName = ConvertTo-StorageAccountName -Name:$Identity

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


#Deploy Azure Function
$Environment = @{
    Name              = $Identity
    ResourceGroup     = $Identity
    Location          = $location
    DeploymentPackage = "$PSScriptRoot\..\Secrets\FunctionApp1.zip"
    AppSettings       = @{
        FUNCTIONS_EXTENSION_VERSION               = "~1"
    }
    ConnectionStrings = @(
        [pscustomobject] @{
            Name  = "SQLConnectionString"
            Value = "Data Source=$($Parameters.Name.ToLower()).database.windows.net;Initial Catalog=$($SQLDatabase)"
            Type  = "SQLAzure"
        })
    AllowedOrigins    = @("https://" + $SharePoint)
}

dotnet build "$PSScriptRoot\..\FunctionApp1\FunctionApp1.sln" --configuration Release
Write-Information -MessageData:"Creating the $($Environment.Name) Azure Function App deployment package"
Compress-Archive -Path:"$PSScriptRoot\..\FunctionApp1\FunctionApp1\bin\release\net461\*" `
    -DestinationPath:$Environment.DeploymentPackage `
    -Force

Set-AzureFuncionApp @Environment -Verbose:$VerbosePreference

Write-Output $SQLAppPassword
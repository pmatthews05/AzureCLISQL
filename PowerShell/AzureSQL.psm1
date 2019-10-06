param (
    [Parameter(Position = 0)]
    [string]
    $ErrorActionOverride = $(throw "You must supply an error action preference"),

    [Parameter(Position = 1)]
    [string]
    $InformationOverride = $(throw "You must supply an information preference"),

    [Parameter(Position = 2)]
    [string]
    $VerboseOverride = $(throw "You must supply a verbose preference")
)

$ErrorActionPreference = $ErrorActionOverride
$InformationPreference = $InformationOverride
$VerbosePreference = $VerboseOverride

function Get-AADToken {
    param (
        [Parameter(Mandatory)]
        [String]$TenantID,
        [Parameter(Mandatory)]
        [string]$ServicePrincipalId,
        [Parameter(Mandatory)]
        [string]$ServicePrincipalPwd,
        [Parameter(Mandatory)]
        [string]$resourceAppIdURI
    )
    Try {
        $PNPModule = Get-Module -ListAvailable -Name SharePointPnPPowerShellOnline | Select-Object -First 1
        $adal = Join-Path $PNPModule.ModuleBase Microsoft.IdentityModel.Clients.ActiveDirectory.dll
        [System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
        # Set Authority to Azure AD Tenant
        $authority = 'https://login.windows.net/' + $TenantId        
        $ClientCred = [Microsoft.IdentityModel.Clients.ActiveDirectory.ClientCredential]::new($ServicePrincipalId, $ServicePrincipalPwd)
        $authContext = [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext]::new($authority)
        $authResult = $authContext.AcquireTokenAsync($resourceAppIdURI, $ClientCred)
        $Token = $authResult.Result.AccessToken
    }
    Catch {
        Write-Error -Message $ErrorMessage
        Throw $_
    }
    Write-Output $Token
}

function Invoke-SQLQuery {
    param(
        [Parameter(Mandatory)]
        [string]$Server,
        [Parameter(Mandatory)]
        [string]$DatabaseName,
        [Parameter(Mandatory)]
        [string]$Query,
        [Parameter(Mandatory)]
        [string]$AADToken
    )

    $conn = New-Object System.Data.SqlClient.SQLConnection
    $conn.ConnectionString = "Data Source=$Server;Initial Catalog=$DatabaseName;Connect Timeout=30"
    $conn.AccessToken = $($AADToken)
    
    $conn.Open()
    $command = New-Object -TypeName System.Data.SqlClient.SqlCommand($Query, $conn)
    $command.ExecuteNonQuery()
    $conn.Close()
}
function ConvertTo-StorageAccountName {
    param(
        # The generic name to use for all related assets
        [Parameter(Mandatory)]
        [string]
        $Name
    )

    $StorageAccountName = $($Name -replace '-', '').ToLowerInvariant()
    if ($StorageAccountName.Length -gt 24) {
        $StorageAccountName = $StorageAccountName.Substring(0, 24);
    }
    

    Write-Output $StorageAccountName
}

function ConvertTo-EscapedString {
    param(
        # The string to escape
        [Parameter(Mandatory)][string]$String
    )

    return $String -replace '\^', '^^^^' `
        -replace '\\', '\\' `
        -replace '>', '^^^>' `
        -replace '<', '^^^<' `
        -replace '\"', '\"' `
        -replace '\|', '^^^|' `
        -replace '\&', '^^^&' `
        -replace '\)', '^^^)'
}
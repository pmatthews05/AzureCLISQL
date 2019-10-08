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
        Write-Information -MessageData "Getting PNP Info"
        $PNPModule = Get-Module -ListAvailable SharePointPnPPowerShellOnline -Refresh | Select-Object -First 1
        
        Write-Information -MessageData "Module Location: $($PNPModule.ModuleBase)"

        $adal = Join-Path $PNPModule.ModuleBase Microsoft.IdentityModel.Clients.ActiveDirectory.dll
        Write-Information -MessageData $adal

        [System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
        Write-Information -MessageData "Getting authority Info"
        # Set Authority to Azure AD Tenant
        $authority = 'https://login.windows.net/' + $TenantId        
        $ClientCred = [Microsoft.IdentityModel.Clients.ActiveDirectory.ClientCredential]::new($ServicePrincipalId, $ServicePrincipalPwd)
        $authContext = [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext]::new($authority, $null)
        Write-Information -MessageData "$($authContext.TokenCache)"
        Write-Information -MessageData "Getting authResult"
        $authResult = $authContext.AcquireTokenAsync($resourceAppIdURI, $ClientCred).GetAwaiter().GetResult()
        
        if ($authResult) {
            Write-Information -MessageData:"Found an AuthResult"
            Write-Information -MessageData:$authResult
            if ($authResult.Exception.InnerException.Message) {
                Write-Information -MessageData:"Found an Exception"
                Write-Information -MessageData: $authResult.Exception.InnerException.Message
                Write-Error -Message $authResult.Exception.InnerException.Message
            }
            else {
                Write-Information -MessageData:"Getting the Access Token value."
                $Token = $authResult.AccessToken    
                Write-Output $Token
            }
        }
    }
    Catch {
        Write-Information -MessageData "Found an error"
        Write-Error -Message $_.Exception.Message
        Throw $_.Exception
    }
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
        [string]$AADToken,

        [int]$retryCount = 5,
        [int]$delaySeconds = 1
    )

    $conn = New-Object System.Data.SqlClient.SQLConnection
    $conn.ConnectionString = "Data Source=$Server;Initial Catalog=$DatabaseName;Connect Timeout=30"
    $conn.AccessToken = $($AADToken)
    
    $retryAfterInterval = 0;
    $retryAttempts = 0;
    $backoffInterval = $delaySeconds;

    [int[]]$TransientErrorNumbers = 4060,40197,40501,40613,49918,49919,49920,11001

    while ($retryAttempts -lt $retryCount) {
        try{
            $conn.Open()
            $command = New-Object -TypeName System.Data.SqlClient.SqlCommand($Query, $conn)
            $command.ExecuteNonQuery()
            $conn.Close()
            break;
        }
        Catch [System.Data.SqlClient.SqlException] {
            if($TransientErrorNumbers.Contains($_.Exception.Number))
            {
                Write-Information -MessageData:"$($_.Exception.Number): transient occurred."
                $retryAfterInterval = $backoffInterval
                Start-Sleep -Seconds:$delaySeconds
                $retryAttempts++
                $backoffInterval *= 2
            }else
            {
               Write-Error -Message $_.Exception.Message    
            }
        }
        Catch{
            Write-Error -Message $_.Exception.Message
        }
    }
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

function Set-AzureFuncionApp {
    param(
        # The generic name to use for all related assets
        [Parameter(Mandatory)]
        [string]
        $Name,

        [Parameter(Mandatory)]
        [string]
        $ResourceGroup,
    
        # The location to create the asset in
        [Parameter(Mandatory)]
        [string]
        $Location,
    
        # The path to the deployment package
        [Parameter(Mandatory)]
        [string]
        $DeploymentPackage,
    
        # The application Settings
        $AppSettings = @{ },

        $ConnectionStrings = @(),
    
        # The allowed origins for Cross Origin Request Sharing (CORS)
        [string[]]
        $AllowedOrigins = @()
    )
    Write-Information -Message:"Deploying source for $Name function app"
    az functionapp deployment source config-zip --resource-group $ResourceGroup --name $Name --src $DeploymentPackage | Out-Null

    Write-Information -Message:"Configure $Name function app CORS"
    $AllowedOrigins | ForEach-Object {
        $origin = $PSItem
        $ExistOrigin = az functionapp cors show --resource-group $ResourceGroup --name $Name --query "allowedOrigins | [?contains(@, '$origin')]" | ForEach-Object { $PSItem -join '' } | ConvertFrom-Json

        if (-not $ExistOrigin) {
            Write-Information -Message:"Adding the $Name CORS Value $origin"
            az functionapp cors add --name $Name --resource-group $ResourceGroup --allowed-origins $origin | Out-Null
        }
    }

    Write-Information -Message:"Configure $Name function app settings"
    $AppSettings.Keys | ForEach-Object {
        $Key = $PSItem
        $Value = $AppSettings."$Key"
        Write-Information -Message:"Configure $Key function app settings"
        az functionapp config appsettings set --name $name --settings $Key=$Value --resource-group $ResourceGroup | Out-Null
    }

    Write-Information -Message:"Configure $Name function ConnectionStrings"
    $ConnectionStrings | ForEach-Object {
        $connectionString = $PSItem
        Write-Information -Message:"Configure $($PSItem.Name) function app settings"
        az webapp config connection-string set --resource-group $ResourceGroup --name $Name --connection-string-type $connectionString.Type --settings "$($connectionString.Name)=$($connectionString.Value)" | Out-Null
    }

}
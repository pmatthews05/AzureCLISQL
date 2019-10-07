# AzureCLISQL

## Introduction
This project shows how to create a Azure environment with Azure SQL. The creation of the SQL will use a Service Principal as Administrator, and a Function App Identity as the member of the SQL database.

All deployable via a script that uses Az CLI. 

### Dependency

- You will require to install [AZ cli](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
- You will require to intall [PNP Powershell](https://docs.microsoft.com/en-us/powershell/sharepoint/sharepoint-pnp/sharepoint-pnp-cmdlets?view=sharepoint-ps)

## Create a Secret File
For the project you will need a secret.json file. Create a Folder called '<b>Secrets</b>'.

### Add a Json file

```json
{
    "Tenant" : "<Tenant>",
    "Name": "SQLExample",
    "AzureSubscription": "Visual Studio Enterprise with MSDN",
    "Location": "uksouth",
    "SQLDatabase": {
       "AdminUser": "SQLAdminUser",
       "Password": "[Random Password Required]",
       "DatabaseName": "Example",
       "SQLAdminAppPrincipalName": "SQLAdminAppPrincipal",
       "SQLDBAccessGroup": "SQLGeneralUsersADGroup",
       "SQLAdminADGroup": "SQLAdminADGroup"
    }
 }
```
- Change the &lt;tenant&gt; name to the name of your tenant. E.g, cfcode.
- Change the AzureSubscription to match with your Azure Subscription Name. 
- Change the [Random Password Required] to a random password you wish to use.


### Run Script.
This will install 
```Powershell
cd .\Powershell
.\Install-SQL.ps1 -path:..\Secrets\secret.json
```

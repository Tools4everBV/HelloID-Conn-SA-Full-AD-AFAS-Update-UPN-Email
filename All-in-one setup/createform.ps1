# Set TLS to accept TLS, TLS 1.1 and TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

#HelloID variables
#Note: when running this script inside HelloID; portalUrl and API credentials are provided automatically (generate and save API credentials first in your admin panel!)
$portalUrl = "https://CUSTOMER.helloid.com"
$apiKey = "API_KEY"
$apiSecret = "API_SECRET"
$delegatedFormAccessGroupNames = @("") #Only unique names are supported. Groups must exist!
$delegatedFormCategories = @("Active Directory","User Management") #Only unique names are supported. Categories will be created if not exists
$script:debugLogging = $false #Default value: $false. If $true, the HelloID resource GUIDs will be shown in the logging
$script:duplicateForm = $false #Default value: $false. If $true, the HelloID resource names will be changed to import a duplicate Form
$script:duplicateFormSuffix = "_tmp" #the suffix will be added to all HelloID resource names to generate a duplicate form with different resource names

#The following HelloID Global variables are used by this form. No existing HelloID global variables will be overriden only new ones are created.
#NOTE: You can also update the HelloID Global variable values afterwards in the HelloID Admin Portal: https://<CUSTOMER>.helloid.com/admin/variablelibrary
$globalHelloIDVariables = [System.Collections.Generic.List[object]]@();

#Global variable #1 >> AFASBaseUrl
$tmpName = @'
AFASBaseUrl
'@ 
$tmpValue = @'
https://<CUSTOMER>.afas.online/profitrestservices
'@ 
$globalHelloIDVariables.Add([PSCustomObject]@{name = $tmpName; value = $tmpValue; secret = "False"});

#Global variable #2 >> AFASToken
$tmpName = @'
AFASToken
'@ 
$tmpValue = "" 
$globalHelloIDVariables.Add([PSCustomObject]@{name = $tmpName; value = $tmpValue; secret = "True"});

#Global variable #3 >> ADusersSearchOU
$tmpName = @'
ADusersSearchOU
'@ 
$tmpValue = @'
OU=Users,OU=enyoi,DC=enyoi,DC=local;OU=UsersLite,OU=enyoi,DC=enyoi,DC=local
'@ 
$globalHelloIDVariables.Add([PSCustomObject]@{name = $tmpName; value = $tmpValue; secret = "False"});


#make sure write-information logging is visual
$InformationPreference = "continue"

# Check for prefilled API Authorization header
if (-not [string]::IsNullOrEmpty($portalApiBasic)) {
    $script:headers = @{"authorization" = $portalApiBasic}
    Write-Information "Using prefilled API credentials"
} else {
    # Create authorization headers with HelloID API key
    $pair = "$apiKey" + ":" + "$apiSecret"
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
    $base64 = [System.Convert]::ToBase64String($bytes)
    $key = "Basic $base64"
    $script:headers = @{"authorization" = $Key}
    Write-Information "Using manual API credentials"
}

# Check for prefilled PortalBaseURL
if (-not [string]::IsNullOrEmpty($portalBaseUrl)) {
    $script:PortalBaseUrl = $portalBaseUrl
    Write-Information "Using prefilled PortalURL: $script:PortalBaseUrl"
} else {
    $script:PortalBaseUrl = $portalUrl
    Write-Information "Using manual PortalURL: $script:PortalBaseUrl"
}

# Define specific endpoint URI
$script:PortalBaseUrl = $script:PortalBaseUrl.trim("/") + "/"  

# Make sure to reveive an empty array using PowerShell Core
function ConvertFrom-Json-WithEmptyArray([string]$jsonString) {
    # Running in PowerShell Core?
    if($IsCoreCLR -eq $true){
        $r = [Object[]]($jsonString | ConvertFrom-Json -NoEnumerate)
        return ,$r  # Force return value to be an array using a comma
    } else {
        $r = [Object[]]($jsonString | ConvertFrom-Json)
        return ,$r  # Force return value to be an array using a comma
    }
}

function Invoke-HelloIDGlobalVariable {
    param(
        [parameter(Mandatory)][String]$Name,
        [parameter(Mandatory)][String][AllowEmptyString()]$Value,
        [parameter(Mandatory)][String]$Secret
    )

    $Name = $Name + $(if ($script:duplicateForm -eq $true) { $script:duplicateFormSuffix })

    try {
        $uri = ($script:PortalBaseUrl + "api/v1/automation/variables/named/$Name")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false

        if ([string]::IsNullOrEmpty($response.automationVariableGuid)) {
            #Create Variable
            $body = @{
                name     = $Name;
                value    = $Value;
                secret   = $Secret;
                ItemType = 0;
            }    
            $body = ConvertTo-Json -InputObject $body -Depth 100

            $uri = ($script:PortalBaseUrl + "api/v1/automation/variable")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
            $variableGuid = $response.automationVariableGuid

            Write-Information "Variable '$Name' created$(if ($script:debugLogging -eq $true) { ": " + $variableGuid })"
        } else {
            $variableGuid = $response.automationVariableGuid
            Write-Warning "Variable '$Name' already exists$(if ($script:debugLogging -eq $true) { ": " + $variableGuid })"
        }
    } catch {
        Write-Error "Variable '$Name', message: $_"
    }
}

function Invoke-HelloIDAutomationTask {
    param(
        [parameter(Mandatory)][String]$TaskName,
        [parameter(Mandatory)][String]$UseTemplate,
        [parameter(Mandatory)][String]$AutomationContainer,
        [parameter(Mandatory)][String][AllowEmptyString()]$Variables,
        [parameter(Mandatory)][String]$PowershellScript,
        [parameter()][String][AllowEmptyString()]$ObjectGuid,
        [parameter()][String][AllowEmptyString()]$ForceCreateTask,
        [parameter(Mandatory)][Ref]$returnObject
    )

    $TaskName = $TaskName + $(if ($script:duplicateForm -eq $true) { $script:duplicateFormSuffix })

    try {
        $uri = ($script:PortalBaseUrl +"api/v1/automationtasks?search=$TaskName&container=$AutomationContainer")
        $responseRaw = (Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false) 
        $response = $responseRaw | Where-Object -filter {$_.name -eq $TaskName}

        if([string]::IsNullOrEmpty($response.automationTaskGuid) -or $ForceCreateTask -eq $true) {
            #Create Task

            $body = @{
                name                = $TaskName;
                useTemplate         = $UseTemplate;
                powerShellScript    = $PowershellScript;
                automationContainer = $AutomationContainer;
                objectGuid          = $ObjectGuid;
                variables           = (ConvertFrom-Json-WithEmptyArray($Variables));
            }
            $body = ConvertTo-Json -InputObject $body -Depth 100

            $uri = ($script:PortalBaseUrl +"api/v1/automationtasks/powershell")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
            $taskGuid = $response.automationTaskGuid

            Write-Information "Powershell task '$TaskName' created$(if ($script:debugLogging -eq $true) { ": " + $taskGuid })"
        } else {
            #Get TaskGUID
            $taskGuid = $response.automationTaskGuid
            Write-Warning "Powershell task '$TaskName' already exists$(if ($script:debugLogging -eq $true) { ": " + $taskGuid })"
        }
    } catch {
        Write-Error "Powershell task '$TaskName', message: $_"
    }

    $returnObject.Value = $taskGuid
}

function Invoke-HelloIDDatasource {
    param(
        [parameter(Mandatory)][String]$DatasourceName,
        [parameter(Mandatory)][String]$DatasourceType,
        [parameter(Mandatory)][String][AllowEmptyString()]$DatasourceModel,
        [parameter()][String][AllowEmptyString()]$DatasourceStaticValue,
        [parameter()][String][AllowEmptyString()]$DatasourcePsScript,        
        [parameter()][String][AllowEmptyString()]$DatasourceInput,
        [parameter()][String][AllowEmptyString()]$AutomationTaskGuid,
        [parameter()][String][AllowEmptyString()]$DatasourceRunInCloud,
        [parameter(Mandatory)][Ref]$returnObject
    )

    $DatasourceName = $DatasourceName + $(if ($script:duplicateForm -eq $true) { $script:duplicateFormSuffix })

    $datasourceTypeName = switch($DatasourceType) { 
        "1" { "Native data source"; break} 
        "2" { "Static data source"; break} 
        "3" { "Task data source"; break} 
        "4" { "Powershell data source"; break}
    }

    try {
        $uri = ($script:PortalBaseUrl +"api/v1/datasource/named/$DatasourceName")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
    
        if([string]::IsNullOrEmpty($response.dataSourceGUID)) {
            #Create DataSource
            $body = @{
                name               = $DatasourceName;
                type               = $DatasourceType;
                model              = (ConvertFrom-Json-WithEmptyArray($DatasourceModel));
                automationTaskGUID = $AutomationTaskGuid;
                value              = (ConvertFrom-Json-WithEmptyArray($DatasourceStaticValue));
                script             = $DatasourcePsScript;
                input              = (ConvertFrom-Json-WithEmptyArray($DatasourceInput));
                runInCloud         = $DatasourceRunInCloud;
            }
            $body = ConvertTo-Json -InputObject $body -Depth 100
    
            $uri = ($script:PortalBaseUrl +"api/v1/datasource")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
            
            $datasourceGuid = $response.dataSourceGUID
            Write-Information "$datasourceTypeName '$DatasourceName' created$(if ($script:debugLogging -eq $true) { ": " + $datasourceGuid })"
        } else {
            #Get DatasourceGUID
            $datasourceGuid = $response.dataSourceGUID
            Write-Warning "$datasourceTypeName '$DatasourceName' already exists$(if ($script:debugLogging -eq $true) { ": " + $datasourceGuid })"
        }
    } catch {
        Write-Error "$datasourceTypeName '$DatasourceName', message: $_"
    }

    $returnObject.Value = $datasourceGuid
}

function Invoke-HelloIDDynamicForm {
    param(
        [parameter(Mandatory)][String]$FormName,
        [parameter(Mandatory)][String]$FormSchema,
        [parameter(Mandatory)][Ref]$returnObject
    )

    $FormName = $FormName + $(if ($script:duplicateForm -eq $true) { $script:duplicateFormSuffix })

    try {
        try {
            $uri = ($script:PortalBaseUrl +"api/v1/forms/$FormName")
            $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
        } catch {
            $response = $null
        }

        if(([string]::IsNullOrEmpty($response.dynamicFormGUID)) -or ($response.isUpdated -eq $true)) {
            #Create Dynamic form
            $body = @{
                Name       = $FormName;
                FormSchema = (ConvertFrom-Json-WithEmptyArray($FormSchema));
            }
            $body = ConvertTo-Json -InputObject $body -Depth 100

            $uri = ($script:PortalBaseUrl +"api/v1/forms")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body

            $formGuid = $response.dynamicFormGUID
            Write-Information "Dynamic form '$formName' created$(if ($script:debugLogging -eq $true) { ": " + $formGuid })"
        } else {
            $formGuid = $response.dynamicFormGUID
            Write-Warning "Dynamic form '$FormName' already exists$(if ($script:debugLogging -eq $true) { ": " + $formGuid })"
        }
    } catch {
        Write-Error "Dynamic form '$FormName', message: $_"
    }

    $returnObject.Value = $formGuid
}


function Invoke-HelloIDDelegatedForm {
    param(
        [parameter(Mandatory)][String]$DelegatedFormName,
        [parameter(Mandatory)][String]$DynamicFormGuid,
        [parameter()][Array][AllowEmptyString()]$AccessGroups,
        [parameter()][String][AllowEmptyString()]$Categories,
        [parameter(Mandatory)][String]$UseFaIcon,
        [parameter()][String][AllowEmptyString()]$FaIcon,
        [parameter()][String][AllowEmptyString()]$task,
        [parameter(Mandatory)][Ref]$returnObject
    )
    $delegatedFormCreated = $false
    $DelegatedFormName = $DelegatedFormName + $(if ($script:duplicateForm -eq $true) { $script:duplicateFormSuffix })

    try {
        try {
            $uri = ($script:PortalBaseUrl +"api/v1/delegatedforms/$DelegatedFormName")
            $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
        } catch {
            $response = $null
        }

        if([string]::IsNullOrEmpty($response.delegatedFormGUID)) {
            #Create DelegatedForm
            $body = @{
                name            = $DelegatedFormName;
                dynamicFormGUID = $DynamicFormGuid;
                isEnabled       = "True";
                useFaIcon       = $UseFaIcon;
                faIcon          = $FaIcon;
                task            = ConvertFrom-Json -inputObject $task;
            }
            if(-not[String]::IsNullOrEmpty($AccessGroups)) { 
                $body += @{
                    accessGroups    = (ConvertFrom-Json-WithEmptyArray($AccessGroups));
                }
            }
            $body = ConvertTo-Json -InputObject $body -Depth 100

            $uri = ($script:PortalBaseUrl +"api/v1/delegatedforms")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body

            $delegatedFormGuid = $response.delegatedFormGUID
            Write-Information "Delegated form '$DelegatedFormName' created$(if ($script:debugLogging -eq $true) { ": " + $delegatedFormGuid })"
            $delegatedFormCreated = $true

            $bodyCategories = $Categories
            $uri = ($script:PortalBaseUrl +"api/v1/delegatedforms/$delegatedFormGuid/categories")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $bodyCategories
            Write-Information "Delegated form '$DelegatedFormName' updated with categories"
        } else {
            #Get delegatedFormGUID
            $delegatedFormGuid = $response.delegatedFormGUID
            Write-Warning "Delegated form '$DelegatedFormName' already exists$(if ($script:debugLogging -eq $true) { ": " + $delegatedFormGuid })"
        }
    } catch {
        Write-Error "Delegated form '$DelegatedFormName', message: $_"
    }

    $returnObject.value.guid = $delegatedFormGuid
    $returnObject.value.created = $delegatedFormCreated
}

<# Begin: HelloID Global Variables #>
foreach ($item in $globalHelloIDVariables) {
	Invoke-HelloIDGlobalVariable -Name $item.name -Value $item.value -Secret $item.secret 
}
<# End: HelloID Global Variables #>


<# Begin: HelloID Data sources #>
<# Begin: DataSource "ad-afas-account-update-upn-email | AD-AFAS-account-update-upn-email-validation" #>
$tmpPsScript = @'
# variables configured in form:
$user = $datasource.user
$blnmail = [System.Convert]::ToBoolean($datasource.blnMail)
$blnupn = [System.Convert]::ToBoolean($datasource.blnUPN)
$newMailAddress = $datasource.newMail
$newUserPrincipalName = $datasource.newUPN
$searchUpperCaseEmail = $newMailAddress
$searchLowerCaseEmail = $newMailAddress
$searchUpperCaseUPN = $newUserPrincipalName
$searchLowerCaseUPN = $newUserPrincipalName
$outputText = [System.Collections.Generic.List[PSCustomObject]]::new()

# Global variables
$searchOUs = $ADusersSearchOU

# Fixed values
$propertiesToSelect = @(                    
    "SamAccountName",
    "mail",
    "Name",
    "DisplayName",
    "UserPrincipalName",
    "Enabled", 
    "ObjectGuid"
) # Properties to select from Microsoft AD, comma separated

# Set debug logging
$VerbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

#region lookup
try {
    $actionMessage = "validating new UPN and mail values"

    if ($blnupn -and ([string]::IsNullOrWhiteSpace($newUserPrincipalName) -or ($user.UserPrincipalName -eq $newUserPrincipalName))) {
        Write-information "UPN [$($user.userPrincipalName)]for user [$($user.userPrincipalName)] with objectguid [$($user.ObjectGuid)] has not been changed"
    }
    if ($blnmail -and ([string]::IsNullOrWhiteSpace($newMailAddress) -or ($user.mail -eq $newMailAddress))) {
        Write-information "Mail [$($user.mail)] for user [$($user.mail)] with objectguid [$($user.ObjectGuid)] has not been changed"
    }

    $actionMessage = "checking AD for uniqueness"

    $filter = "(ObjectGuid -ne '$($user.ObjectGuid)')"

    $filterParts = @()

    if ($blnmail -and -not [string]::IsNullOrWhiteSpace($newMailAddress)) {
        $filterParts += "(mail -eq '$newMailAddress' -or ProxyAddresses -eq 'SMTP:$($newMailAddress.ToUpperInvariant())' -or ProxyAddresses -eq 'smtp:$($newMailAddress.ToLowerInvariant())')"
    }

    if ($blnupn -and -not [string]::IsNullOrWhiteSpace($newUserPrincipalName)) {
        $filterParts += "(UserPrincipalName -eq '$newUserPrincipalName' -or ProxyAddresses -eq 'SMTP:$($newUserPrincipalName.ToUpperInvariant())' -or ProxyAddresses -eq 'smtp:$($newUserPrincipalName.ToLowerInvariant())')"
    }

    if ($filterParts.Count -eq 0) {
        # Nothing to validate for uniqueness
        $filter = "(ObjectGuid -ne '$($user.ObjectGuid)')"
        # Optional: skip Get-ADUser and return Valid directly
    }
    else {
        $filter = "(ObjectGuid -ne '$($user.ObjectGuid)') -and (" + ($filterParts -join ' -or ') + ")"
    }

    Write-Information "SearchBase: $searchOUs"
    
    $ous = $searchOUs -split ';'
    $users = foreach ($item in $ous) {
        $getAdUsersSplatParams = @{
            Filter      = $filter
            Properties  = $propertiesToSelect
            SearchBase  = $item
            Verbose     = $false
            ErrorAction = 'Stop'
        }
        Get-AdUser @getAdUsersSplatParams | Select-Object -Property $propertiesToSelect
    }

    #region Sorting user object(s)
    $users = $users | Sort-Object -Property DisplayName
    $resultCount = @($users).Count
    Write-Information "Result count: $resultCount"

    foreach ($user in $users) {
        if ($user.UserPrincipalName -eq $newUserPrincipalName -and $blnupn) {
            $outputText.Add([PSCustomObject]@{
                    Message  = "UPN [$newUserPrincipalName] not unique, found on [$($user.Name)]"
                    IsError  = $true
                    Property = "UPN"
                })
        }
        if ($user.mail -eq $newMailAddress -and $blnmail) {
            $outputText.Add([PSCustomObject]@{
                    Message  = "Email [$newMailAddress] not unique, found on [$($user.Name)]"
                    IsError  = $true
                    Property = "Email"
                })
        }
        elseif (($user.ProxyAddresses -eq "SMTP:$newUserPrincipalName") -or ($record.ProxyAddresses -eq "smtp:$newUserPrincipalName") -and $blnupn) {
            $outputText.Add([PSCustomObject]@{
                    Message  = "ProxyAddress [$newUserPrincipalName] not unique, found on [$($user.Name)]"
                    IsError  = $true
                    Property = "ProxyAddress"
                })
        }
        elseif (($user.ProxyAddresses -eq "SMTP:$newMailAddress") -or ($record.ProxyAddresses -eq "smtp:$newMailAddress") -and $blnmail) {
            $outputText.Add([PSCustomObject]@{
                    Message  = "ProxyAddress [$newMailAddress] not unique, found on [$($user.Name)]"
                    IsError  = $true
                    Property = "ProxyAddress"
                })
        }
    }

    if ($outputText.isError -contains - $true) {
        $outputMessage = "Invalid"
    }
    else {
        $outputMessage = "Valid"
        if ($blnupn) {
            $outputText.Add([PSCustomObject]@{
                    Message  = "UPN [$newUserPrincipalName] unique"
                    IsError  = $false
                    Property = "UPN"
                })
        }
        if ($blnmail) {
            $outputText.Add([PSCustomObject]@{
                    Message  = "Email [$newMailAddress] unique"
                    IsError  = $false
                    Property = "Email"
                })
        }
    }

    foreach ($text in $outputText) {
        $outputMessage += "`n" + $($text.Message)
    }

    Write-Output $outputMessage  
}
catch {
    $ex = $PSItem
    Write-Warning "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    Write-Error "Error $($actionMessage). Error: $($ex.Exception.Message)"
}
#endregion lookup
'@ 
$tmpModel = @'
[{"key":"output","type":0}]
'@ 
$tmpInput = @'
[{"description":null,"translateDescription":false,"inputFieldType":1,"key":"newUPN","type":0,"options":0},{"description":null,"translateDescription":false,"inputFieldType":1,"key":"newMail","type":0,"options":0},{"description":null,"translateDescription":false,"inputFieldType":1,"key":"blnMail","type":0,"options":0},{"description":null,"translateDescription":false,"inputFieldType":1,"key":"blnUPN","type":0,"options":0},{"description":null,"translateDescription":false,"inputFieldType":1,"key":"user","type":0,"options":0}]
'@ 
$dataSourceGuid_1 = [PSCustomObject]@{} 
$dataSourceGuid_1_Name = @'
ad-afas-account-update-upn-email | AD-AFAS-account-update-upn-email-validation
'@ 
Invoke-HelloIDDatasource -DatasourceName $dataSourceGuid_1_Name -DatasourceType "4" -DatasourceInput $tmpInput -DatasourcePsScript $tmpPsScript -DatasourceModel $tmpModel -DataSourceRunInCloud "False" -returnObject ([Ref]$dataSourceGuid_1) 
<# End: DataSource "ad-afas-account-update-upn-email | AD-AFAS-account-update-upn-email-validation" #>

<# Begin: DataSource "ad-afas-account-update-upn-email | AD-Get-Active-Users-DisplayName-Mail-Name-UserprincipalName" #>
$tmpPsScript = @'
# Variables configured in form
$searchValue = $dataSource.searchUser
if ($searchValue -eq "*") {
    $filter = "Name -like '*'"
}
else {
    $filter = "Name -like '*$searchValue*' -or DisplayName -like '*$searchValue*' -or userPrincipalName -like '*$searchValue*' -or mail -like '*$searchValue*'"
}
# Global variables
$searchOUs = $AdUsersSearchOu

# Fixed values
$propertiesToSelect = @(                    
    "SamAccountName",
    "DisplayName",
    "UserPrincipalName",
    "mail",
    "ObjectGuid",
    "EmployeeID"
) # Properties to select from Microsoft AD, comma separated

# Set debug logging
$VerbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

try {
    #region Searching user
    $actionMessage = "searching AD account(s) with the value entered [$($searchValue)]"

    if ([String]::IsNullOrEmpty($searchValue) -eq $true) {
        return
    }
    else {
        Write-Information "SearchQuery: $searchQuery"
        Write-Information "SearchBase: $searchOUs"
         
        $ous = $searchOUs -split ';'
        $users = foreach ($item in $ous) {
            $getAdUsersSplatParams = @{
                Filter      = $filter
                Searchbase  = $item
                Properties  = $propertiesToSelect
                Verbose     = $False
                ErrorAction = "Stop"
            }
            Get-AdUser @getAdUsersSplatParams | Select-Object -Property $propertiesToSelect
        }
         
        $users = $users | Sort-Object -Property DisplayName
        $resultCount = @($users).Count
        Write-Information "Result count: $resultCount"
         
        if ($resultCount -gt 0) {
            foreach ($user in $users) {
                Write-Output $user
            }
        }
    }
}
catch {
    $ex = $PSItem
    Write-Warning "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    Write-Error "Error $($actionMessage). Error: $($ex.Exception.Message)"
    # exit # use when using multiple try/catch and the script must stop
}
'@ 
$tmpModel = @'
[{"key":"SamAccountName","type":0},{"key":"DisplayName","type":0},{"key":"UserPrincipalName","type":0},{"key":"mail","type":0},{"key":"ObjectGuid","type":0}]
'@ 
$tmpInput = @'
[{"description":null,"translateDescription":false,"inputFieldType":1,"key":"searchUser","type":0,"options":1}]
'@ 
$dataSourceGuid_0 = [PSCustomObject]@{} 
$dataSourceGuid_0_Name = @'
ad-afas-account-update-upn-email | AD-Get-Active-Users-DisplayName-Mail-Name-UserprincipalName
'@ 
Invoke-HelloIDDatasource -DatasourceName $dataSourceGuid_0_Name -DatasourceType "4" -DatasourceInput $tmpInput -DatasourcePsScript $tmpPsScript -DatasourceModel $tmpModel -DataSourceRunInCloud "False" -returnObject ([Ref]$dataSourceGuid_0) 
<# End: DataSource "ad-afas-account-update-upn-email | AD-Get-Active-Users-DisplayName-Mail-Name-UserprincipalName" #>
<# End: HelloID Data sources #>

<# Begin: Dynamic Form "AD AFAS Account - Update UPN - Email" #>
$tmpSchema = @"
[{"label":"Select user account","fields":[{"key":"searchfield","templateOptions":{"label":"Search (wildcard search in Name, Display name, UserPrincipalName and Mail or use * to search all users)","placeholder":"Name, Display name, UserPrincipalName or Mail (use * to search all users)"},"type":"input","summaryVisibility":"Hide element","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false},{"key":"gridUsers","templateOptions":{"label":"Select user account","required":true,"grid":{"columns":[{"headerName":"Display Name","field":"DisplayName"},{"headerName":"UserPrincipalName","field":"UserPrincipalName"},{"headerName":"Mail","field":"mail"},{"headerName":"Object Guid","field":"ObjectGuid"}],"height":300,"rowSelection":"single"},"dataSourceConfig":{"dataSourceGuid":"$dataSourceGuid_0","input":{"propertyInputs":[{"propertyName":"searchUser","otherFieldValue":{"otherFieldKey":"searchfield"}}]}},"useFilter":false,"allowCsvDownload":true},"type":"grid","summaryVisibility":"Show","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":true}]},{"label":"Details","fields":[{"key":"blnMail","templateOptions":{"label":"Update E-mail","useSwitch":true,"checkboxLabel":""},"type":"boolean","summaryVisibility":"Show","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false},{"key":"formRowMail","templateOptions":{},"fieldGroup":[{"key":"currentMail","templateOptions":{"label":"Current E-mail Address","useDataSource":false,"useDependOn":true,"dependOn":"gridUsers","dependOnProperty":"mail","readonly":true},"hideExpression":"!model[\"blnMail\"]","type":"input","summaryVisibility":"Show","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false},{"key":"newMail","templateOptions":{"label":"New E-mail Address","useDependOn":true,"dependOn":"gridUsers","dependOnProperty":"mail"},"hideExpression":"!model[\"blnMail\"]","type":"input","summaryVisibility":"Show","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false}],"type":"formrow","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false},{"key":"blnUPN","templateOptions":{"label":"Update user principal name","useSwitch":true,"checkboxLabel":""},"type":"boolean","summaryVisibility":"Show","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false},{"key":"formRowUPN","templateOptions":{},"fieldGroup":[{"key":"currentUPN","templateOptions":{"label":"Current user principal name","useDependOn":true,"dependOn":"gridUsers","dependOnProperty":"UserPrincipalName","readonly":true},"hideExpression":"!model[\"blnUPN\"]","type":"input","summaryVisibility":"Show","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false},{"key":"newUPN","templateOptions":{"label":"New user principal name","useDependOn":true,"dependOn":"gridUsers","dependOnProperty":"UserPrincipalName"},"hideExpression":"!model[\"blnUPN\"]","type":"input","summaryVisibility":"Show","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false}],"type":"formrow","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false},{"key":"Validation","templateOptions":{"label":"Validation","readonly":true,"useDataSource":true,"dataSourceConfig":{"dataSourceGuid":"$dataSourceGuid_1","input":{"propertyInputs":[{"propertyName":"newUPN","otherFieldValue":{"otherFieldKey":"newUPN"}},{"propertyName":"newMail","otherFieldValue":{"otherFieldKey":"newMail"}},{"propertyName":"blnMail","otherFieldValue":{"otherFieldKey":"blnMail"}},{"propertyName":"blnUPN","otherFieldValue":{"otherFieldKey":"blnUPN"}},{"propertyName":"user","otherFieldValue":{"otherFieldKey":"gridUsers"}}]}},"displayField":"output","pattern":"^Valid:[\\s\\S]*","required":true},"validation":{"messages":{"pattern":"No valid value"}},"type":"input","summaryVisibility":"Show","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false}]}]
"@ 

$dynamicFormGuid = [PSCustomObject]@{} 
$dynamicFormName = @'
AD AFAS Account - Update UPN - Email
'@ 
Invoke-HelloIDDynamicForm -FormName $dynamicFormName -FormSchema $tmpSchema  -returnObject ([Ref]$dynamicFormGuid) 
<# END: Dynamic Form #>

<# Begin: Delegated Form Access Groups and Categories #>
$delegatedFormAccessGroupGuids = @()
if(-not[String]::IsNullOrEmpty($delegatedFormAccessGroupNames)){
    foreach($group in $delegatedFormAccessGroupNames) {
        try {
            $uri = ($script:PortalBaseUrl +"api/v1/groups/$group")
            $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
            $delegatedFormAccessGroupGuid = $response.groupGuid
            $delegatedFormAccessGroupGuids += $delegatedFormAccessGroupGuid
        
            Write-Information "HelloID (access)group '$group' successfully found$(if ($script:debugLogging -eq $true) { ": " + $delegatedFormAccessGroupGuid })"
        } catch {
            Write-Error "HelloID (access)group '$group', message: $_"
        }
    }
    if($null -ne $delegatedFormAccessGroupGuids){
        $delegatedFormAccessGroupGuids = ($delegatedFormAccessGroupGuids | Select-Object -Unique | ConvertTo-Json -Depth 100 -Compress)
    }
}

$delegatedFormCategoryGuids = @()
foreach($category in $delegatedFormCategories) {
    try {
        $uri = ($script:PortalBaseUrl +"api/v1/delegatedformcategories/$category")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
        $response = $response | Where-Object {$_.name.en -eq $category}
    
        $tmpGuid = $response.delegatedFormCategoryGuid
        $delegatedFormCategoryGuids += $tmpGuid
    
        Write-Information "HelloID Delegated Form category '$category' successfully found$(if ($script:debugLogging -eq $true) { ": " + $tmpGuid })"
    } catch {
        Write-Warning "HelloID Delegated Form category '$category' not found"
        $body = @{
            name = @{"en" = $category};
        }
        $body = ConvertTo-Json -InputObject $body -Depth 100

        $uri = ($script:PortalBaseUrl +"api/v1/delegatedformcategories")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
        $tmpGuid = $response.delegatedFormCategoryGuid
        $delegatedFormCategoryGuids += $tmpGuid

        Write-Information "HelloID Delegated Form category '$category' successfully created$(if ($script:debugLogging -eq $true) { ": " + $tmpGuid })"
    }
}
$delegatedFormCategoryGuids = (ConvertTo-Json -InputObject $delegatedFormCategoryGuids -Depth 100 -Compress)
<# End: Delegated Form Access Groups and Categories #>

<# Begin: Delegated Form #>
$delegatedFormRef = [PSCustomObject]@{guid = $null; created = $null} 
$delegatedFormName = @'
AD AFAS Account - Update UPN - Email
'@
$tmpTask = @'
{"name":"AD AFAS Account - Update UPN - Email","script":"# variables configured in form:\r\n$user = $form.gridUsers\r\n$blnmail = [System.Convert]::ToBoolean($form.blnMail)\r\n$blnupn = [System.Convert]::ToBoolean($form.blnUPN)\r\n$newMailAddress = $form.newMail\r\n$newUserPrincipalName = $form.newUPN\r\n$BaseUrl = $AFASBaseUrl\r\n$Token = $AFASToken\r\n$getConnector = \"T4E_HelloID_Users_v2\"\r\n$updateConnector = \"KnEmployee\"\r\n$filterfieldid = \"Medewerker\"\r\n$filtervalue = $user.employeeID # Has to match the AFAS value of the specified filter field ($filterfieldid)\r\n\r\n# Set debug logging\r\n$VerbosePreference = \"SilentlyContinue\"\r\n$InformationPreference = \"Continue\"\r\n$WarningPreference = \"Continue\"\r\n\r\n#region AFAS functions\r\nfunction Resolve-AFAS-ProfitError {\r\n    [CmdletBinding()]\r\n    param (\r\n        [Parameter(Mandatory)]\r\n        [object]\r\n        $ErrorObject\r\n    )\r\n    process {\r\n        $httpErrorObj = [PSCustomObject]@{\r\n            ScriptLineNumber = $ErrorObject.InvocationInfo.ScriptLineNumber\r\n            Line             = $ErrorObject.InvocationInfo.Line\r\n            ErrorDetails     = $ErrorObject.Exception.Message\r\n            FriendlyMessage  = $ErrorObject.Exception.Message\r\n        }\r\n        if (-not [string]::IsNullOrEmpty($ErrorObject.ErrorDetails.Message)) {\r\n            $httpErrorObj.ErrorDetails = $ErrorObject.ErrorDetails.Message\r\n        }\r\n        elseif ($ErrorObject.Exception.GetType().FullName -eq \u0027System.Net.WebException\u0027) {\r\n            if ($null -ne $ErrorObject.Exception.Response) {\r\n                $streamReaderResponse = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()\r\n                if (-not [string]::IsNullOrEmpty($streamReaderResponse)) {\r\n                    $httpErrorObj.ErrorDetails = $streamReaderResponse\r\n                }\r\n            }\r\n        }\r\n        try {\r\n            $errorDetailsObject = ($httpErrorObj.ErrorDetails | ConvertFrom-Json)\r\n\r\n            if ($null -ne $errorDetailsObject.externalMessage) {\r\n                $httpErrorObj.FriendlyMessage = $errorDetailsObject.externalMessage\r\n            }\r\n            else {\r\n                $httpErrorObj.FriendlyMessage = $errorDetailsObject\r\n            }\r\n        }\r\n        catch {\r\n            $httpErrorObj.FriendlyMessage = \"[$($httpErrorObj.ErrorDetails)]\"\r\n        }\r\n        Write-Output $httpErrorObj\r\n    }\r\n}\r\n\r\ntry {\r\n    $actionMessage = \"updating AD attributes for user [$($user.userPrincipalName)] with objectguid [$($user.ObjectGuid)]\"\r\n\r\n    $proxyAddresses = @()\r\n    foreach ($address in $user.ProxyAddresses) {\r\n        if ($address.StartsWith(\u0027SMTP:\u0027)) {\r\n            $address = $address -replace \u0027SMTP:\u0027, \u0027smtp:\u0027\r\n        }\r\n        if ($address -eq \"smtp:\" + $newMailAddress) {\r\n        }\r\n        else {\r\n            $proxyAddresses += $address\r\n        }\r\n    }\r\n\r\n    $newPrimary = \u0027SMTP:\u0027 + $newMailAddress\r\n    $proxyAddresses += $newPrimary\r\n\r\n    if ($blnupn -eq $true) {\r\n        Set-ADUser -Identity $user.ObjectGuid -userprincipalname $newUserPrincipalName \r\n\r\n        $Log = @{\r\n            Action            = \"UpdateAccount\" # optional. ENUM (undefined = default) \r\n            System            = \"ActiveDirectory\" # optional (free format text) \r\n            Message           = \"Successfully updated AD user [$($user.userPrincipalName)] attributes [userPrincipalName] from [$($user.userPrincipalName)] to [$newUserPrincipalName]\" # required (free format text) \r\n            IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n            TargetDisplayName = $user.userPrincipalName # optional (free format text) \r\n            TargetIdentifier  = $user.ObjectGuid # optional (free format text) \r\n        }\r\n        #send result back  \r\n        Write-Information -Tags \"Audit\" -MessageData $log     \r\n    }\r\n\r\n    if ($blnmail -eq $true) {\r\n        Set-ADUser -Identity $user.ObjectGuid -emailaddress $newMailAddress -Replace @{proxyAddresses = $proxyAddresses }\r\n\r\n        $Log = @{\r\n            Action            = \"UpdateAccount\" # optional. ENUM (undefined = default) \r\n            System            = \"ActiveDirectory\" # optional (free format text) \r\n            Message           = \"Successfully updated AD user [$($user.mail)] attributes [mail] from [$($user.mail)] to [$newMailAddress]\" # required (free format text) \r\n            IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n            TargetDisplayName = $user.userPrincipalName # optional (free format text) \r\n            TargetIdentifier  = $user.ObjectGuid # optional (free format text) \r\n        }\r\n        #send result back  \r\n        Write-Information -Tags \"Audit\" -MessageData $log     \r\n    }\r\n}\r\ncatch {\r\n    $ex = $PSItem\r\n    $auditMessage = \"Error $($actionMessage). Error: $($ex.Exception.Message)\"\r\n    $warningMessage = \"Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)\"  \r\n\r\n    $Log = @{\r\n        Action            = \"UpdateAccount\" # optional. ENUM (undefined = default) \r\n        System            = \"ActiveDirectory\" # optional (free format text) \r\n        Message           = \"Failed to update AD user [$($user.userPrincipalName)] attributes [userPrincipalName] from [$($user.userPrincipalName)] to [$newUserPrincipalName], [emailaddress] from [$($user.mail)] to [$newMailAddress]\" # required (free format text) \r\n        IsError           = $true # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n        TargetDisplayName = $user.userPrincipalName # optional (free format text) \r\n        TargetIdentifier  = $user.ObjectGuid # optional (free format text) \r\n    }\r\n    #send result back  \r\n    Write-Information -Tags \"Audit\" -MessageData $log      \r\n    Write-Warning $warningMessage   \r\n    Write-Error $auditMessage   \r\n}\r\n#endregion AD\r\n\r\n#region AFAS\r\n#AFAS Employee\r\nif (-not([string]::IsNullOrEmpty($user.employeeID))) {\r\n    # Used to connect to AFAS API endpoints\r\n\r\n    #Change mapping here\r\n    $accountEmployee = [PSCustomObject]@{\r\n        \u0027AfasEmployee\u0027 = @{\r\n            \u0027Element\u0027 = @{\r\n                \u0027Objects\u0027 = @(\r\n                    @{\r\n                        \u0027KnPerson\u0027 = @{\r\n                            \u0027Element\u0027 = @{\r\n                                \u0027Fields\u0027 = @{\r\n                                    # E-Mail werk  \r\n                                    \u0027EmAd\u0027 = $newMailAddress\r\n                                }\r\n                            }\r\n                        }\r\n                    }\r\n                )\r\n            }\r\n        }\r\n    }\r\n\r\n    #$filterfieldid = \"Medewerker\"\r\n    #$filtervalue = $user.employeeID # Has to match the AFAS value of the specified filter field ($filterfieldid)\r\n\r\n    # Get current AFAS employee and verify if a user must be either [created], [updated and correlated] or just [correlated]\r\n    try {\r\n        $actionMessage = \"Querying AFAS employee with $($filterfieldid) $($filtervalue)\"\r\n\r\n        # Create authorization headers\r\n        $encodedToken = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($Token))\r\n        $authValue = \"AfasToken $encodedToken\"\r\n        $Headers = @{ Authorization = $authValue }\r\n\r\n        $splatWebRequest = @{\r\n            Uri             = $BaseUrl + \"/connectors/\" + $getConnector + \"?filterfieldids=$filterfieldid\u0026filtervalues=$filtervalue\u0026operatortypes=1\"\r\n            Headers         = $headers\r\n            Method          = \u0027GET\u0027\r\n            ContentType     = \"application/json;charset=utf-8\"\r\n            UseBasicParsing = $true\r\n        }        \r\n        $currentAccount = (Invoke-RestMethod @splatWebRequest -Verbose:$false).rows\r\n\r\n        if ($null -eq $currentAccount.Medewerker) {\r\n            throw \"No AFAS employee found with $($filterfieldid) $($filtervalue)\"\r\n        }\r\n        # Check if current EmAd has a different value from mapped value. AFAS will throw an error when trying to update this with the same value\r\n        if ([string]$currentAccount.Email_werk -ne $accountEmployee.\u0027AfasEmployee\u0027.\u0027Element\u0027.Objects[0].\u0027KnPerson\u0027.\u0027Element\u0027.\u0027Fields\u0027.\u0027EmAd\u0027 -and $null -ne $accountEmployee.\u0027AfasEmployee\u0027.\u0027Element\u0027.Objects[0].\u0027KnPerson\u0027.\u0027Element\u0027.\u0027Fields\u0027.\u0027EmAd\u0027) {\r\n            $propertiesChanged += @(\u0027EmAd\u0027)\r\n        }\r\n\r\n        if ($propertiesChanged) {\r\n            $updateAction = \u0027Update\u0027\r\n        }\r\n        else {\r\n            $updateAction = \u0027NoChanges\u0027\r\n        }\r\n\r\n        # Update AFAS Employee\r\n        switch ($updateAction) {\r\n            \u0027Update\u0027 {\r\n                $actionmessage = \"updating AFAS employee [$($user.EmployeeID)] attributes [EmAd] from [$($currentAccount.Email_werk)] to [$newMailAddress] and/or [Upn] from [$($currentAccount.Upn)] to [$newUserPrincipalName].\"\r\n                # Create custom account object for update\r\n                $updateAccount = [PSCustomObject]@{\r\n                    \u0027AfasEmployee\u0027 = @{\r\n                        \u0027Element\u0027 = @{\r\n                            \u0027@EmId\u0027   = $currentAccount.Medewerker\r\n                            \u0027Objects\u0027 = @(@{\r\n                                    \u0027KnPerson\u0027 = @{\r\n                                        \u0027Element\u0027 = @{\r\n                                            \u0027Fields\u0027 = @{\r\n                                                # Zoek op BcCo (Persoons-ID)\r\n                                                \u0027MatchPer\u0027 = 0\r\n                                                # Nummer\r\n                                                \u0027BcCo\u0027     = $currentAccount.Persoonsnummer\r\n                                            }\r\n                                        }\r\n                                    }\r\n                                })\r\n                        }\r\n                    }\r\n                }\r\n                if (\u0027EmAd\u0027 -in $propertiesChanged) {\r\n                    # E-mail werk\r\n                    $updateAccount.\u0027AfasEmployee\u0027.\u0027Element\u0027.Objects[0].\u0027KnPerson\u0027.\u0027Element\u0027.\u0027Fields\u0027.\u0027EmAd\u0027 = $accountEmployee.\u0027AfasEmployee\u0027.\u0027Element\u0027.Objects[0].\u0027KnPerson\u0027.\u0027Element\u0027.\u0027Fields\u0027.\u0027EmAd\u0027\r\n\r\n                    $body = ($updateAccount | ConvertTo-Json -Depth 10)\r\n                    $splatWebRequest = @{\r\n                        Uri             = $BaseUrl + \"/connectors/\" + $updateConnector\r\n                        Headers         = $headers\r\n                        Method          = \u0027PUT\u0027\r\n                        Body            = ([System.Text.Encoding]::UTF8.GetBytes($body))\r\n                        ContentType     = \"application/json;charset=utf-8\"\r\n                        UseBasicParsing = $true\r\n                    }\r\n\r\n                    $null = Invoke-RestMethod @splatWebRequest -Verbose:$false\r\n                    $Log = @{\r\n                        Action            = \"UpdateAccount\" # optional. ENUM (undefined = default) \r\n                        System            = \"AFAS Employee\" # optional (free format text) \r\n                        Message           = \"Successfully updated attribute [EmAd] of AFAS employee [$($user.employeeID)] from [$($currentAccount.Email_werk)] to [$newMailAddress]\" # required (free format text) \r\n                        IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n                        TargetDisplayName = $user.userPrincipalName # optional (free format text) \r\n                        TargetIdentifier  = $user.ObjectGuid # optional (free format text) \r\n                    }\r\n                    #send result back  \r\n                    Write-Information -Tags \"Audit\" -MessageData $log  \r\n                }\r\n\r\n                break\r\n            }\r\n            \u0027NoChanges\u0027 {\r\n                $Log = @{\r\n                    Action            = \"UpdateAccount\" # optional. ENUM (undefined = default) \r\n                    System            = \"AFAS Employee\" # optional (free format text) \r\n                    Message           = \"Successfully checked attributes [EmAd] and [Upn] of AFAS employee [$($user.employeeID)]: [EmAd] [$($currentAccount.Email_werk)] equals [$newMailAddress] and [Upn] [$($currentAccount.Upn)] equals [$newUserPrincipalName]; no changes needed\" # required (free format text) \r\n                    IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n                    TargetDisplayName = $user.userPrincipalName # optional (free format text) \r\n                    TargetIdentifier  = $user.ObjectGuid # optional (free format text) \r\n                }\r\n                #send result back  \r\n                Write-Information -Tags \"Audit\" -MessageData $log  \r\n                break\r\n            }\r\n        }\r\n    }\r\n    catch {\r\n        $ex = $PSItem\r\n        if ($($ex.Exception.GetType().FullName -eq \u0027Microsoft.PowerShell.Commands.HttpResponseException\u0027) -or\r\n            $($ex.Exception.GetType().FullName -eq \u0027System.Net.WebException\u0027)) {\r\n            $errorObj = Resolve-AFAS-ProfitError -ErrorObject $ex\r\n            $warningMessage = \"Error at Line \u0027$($errorObj.ScriptLineNumber)\u0027: $($errorObj.Line). Error: $($errorObj.ErrorDetails)\"\r\n            $auditMessage = \"Error $($actionMessage). Error: $($errorObj.FriendlyMessage)\"\r\n        }\r\n        else {\r\n            $warningMessage = \"Error at Line \u0027$($ex.InvocationInfo.ScriptLineNumber)\u0027: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)\"\r\n            $auditMessage = \"Error $($actionMessage). Error: $($ex.Exception.Message)\"\r\n        }\r\n        $log = @{\r\n            Action            = \"UpdateAccount\" # optional. ENUM (undefined = default) \r\n            System            = \"AFAS\" # optional (free format text) \r\n            Message           = $auditMessage # required (free format text) \r\n            IsError           = $true # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n            TargetDisplayName = $displayName # optional (free format text) \r\n            TargetIdentifier  = $([string]$employeeID) # optional (free format text) \r\n        }\r\n        Write-Information -Tags \"Audit\" -MessageData $log\r\n        Write-Warning $warningMessage\r\n        Write-Error $auditMessage\r\n        # exit # use when using multiple try/catch and the script must stop\r\n    }\r\n}\r\nelse {\r\n    $Log = @{\r\n        Action            = \"UpdateAccount\" # optional. ENUM (undefined = default) \r\n        System            = \"AFAS Employee\" # optional (free format text) \r\n        Message           = \"Skipped update attributes [EmAd] to [$newMailAddress] of AFAS employee [$($user.employeeID)]: employeeID is empty\" # required (free format text) \r\n        IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n        TargetDisplayName = $user.userPrincipalName # optional (free format text) \r\n        TargetIdentifier  = $user.ObjectGuid # optional (free format text)\r\n    }\r\n    #send result back  \r\n    Write-Information -Tags \"Audit\" -MessageData $log \r\n}\r\n\r\n#AFAS User\r\nif (-not([string]::IsNullOrEmpty($user.employeeID))) {\r\n    # Used to connect to AFAS API endpoints\r\n    try {\r\n        $actionMessage = \"Querying AFAS employee with $($filterfieldid) $($filtervalue)\"\r\n\r\n        # Create authorization headers\r\n        $encodedToken = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($Token))\r\n        $authValue = \"AfasToken $encodedToken\"\r\n        $Headers = @{ Authorization = $authValue }\r\n\r\n        $splatWebRequest = @{\r\n            Uri             = $BaseUrl + \"/connectors/\" + $getConnector + \"?filterfieldids=$filterfieldid\u0026filtervalues=$filtervalue\u0026operatortypes=1\"\r\n            Headers         = $Headers\r\n            Method          = \u0027GET\u0027\r\n            ContentType     = \"application/json;charset=utf-8\"\r\n            UseBasicParsing = $true\r\n        }\r\n        $currentAccount = (Invoke-RestMethod @splatWebRequest -Verbose:$false).rows\r\n\r\n        if ($null -eq $currentAccount.Medewerker) {\r\n            throw \"No AFAS employee found with $($filterfieldid) $($filtervalue)\"\r\n        }\r\n\r\n        $propertiesChanged = @()\r\n\r\n        if (-not [string]::IsNullOrEmpty($newMailAddress) -and [string]$currentAccount.Email_werk_gebruiker -ne $newMailAddress) {\r\n            $propertiesChanged += @(\u0027EmAd\u0027)\r\n        }\r\n        if (-not [string]::IsNullOrEmpty($newUserPrincipalName) -and [string]$currentAccount.Upn -ne $newUserPrincipalName) {\r\n            $propertiesChanged += @(\u0027Upn\u0027)\r\n        }\r\n\r\n        if ($propertiesChanged) {\r\n            $updateAction = \u0027Update\u0027\r\n        }\r\n        else {\r\n            $updateAction = \u0027NoChanges\u0027\r\n        }\r\n\r\n        # Update AFAS User\r\n        switch ($updateAction) {\r\n            \u0027Update\u0027 {\r\n                $actionmessage = \"updating AFAS user [$($user.EmployeeID)] attributes [EmAd] from [$($currentAccount.Email_werk_gebruiker)] to [$newMailAddress] and/or [Upn] from [$($currentAccount.Upn)] to [$newUserPrincipalName].\"\r\n\r\n                $updateAccount = [PSCustomObject]@{\r\n                    \u0027KnUser\u0027 = @{\r\n                        \u0027Element\u0027 = @{\r\n                            # Gebruiker\r\n                            \u0027@UsId\u0027  = $currentAccount.Gebruiker\r\n                            \u0027Fields\u0027 = @{\r\n                                # Mutatie code\r\n                                \u0027MtCd\u0027 = 1\r\n                                # Omschrijving\r\n                                \"Nm\"   = $currentAccount.DisplayName\r\n                            }\r\n                        }\r\n                    }\r\n                }\r\n\r\n                if (\u0027EmAd\u0027 -in $propertiesChanged) {\r\n                    # E-mail werk\r\n                    $updateAccount.\u0027KnUser\u0027.\u0027Element\u0027.\u0027Fields\u0027.\u0027EmAd\u0027 = $newMailAddress\r\n                }\r\n\r\n                if (\u0027Upn\u0027 -in $propertiesChanged) {\r\n                    # UPN\r\n                    $updateAccount.\u0027KnUser\u0027.\u0027Element\u0027.\u0027Fields\u0027.\u0027Upn\u0027 = $newUserPrincipalName\r\n                }\r\n\r\n                $body = ($updateAccount | ConvertTo-Json -Depth 10)\r\n                $splatWebRequest = @{\r\n                    Uri             = $BaseUrl + \"/connectors/KnUser\"\r\n                    Headers         = $Headers\r\n                    Method          = \u0027PUT\u0027\r\n                    Body            = ([System.Text.Encoding]::UTF8.GetBytes($body))\r\n                    ContentType     = \"application/json;charset=utf-8\"\r\n                    UseBasicParsing = $true\r\n                }\r\n\r\n                $null = Invoke-RestMethod @splatWebRequest -Verbose:$false\r\n\r\n                $Log = @{\r\n                    Action            = \"UpdateAccount\"\r\n                    System            = \"AFAS User\"\r\n                    Message           = \"Successfully updated AFAS user [$($user.employeeID)] attributes [EmAd] from [$($currentAccount.Email_werk_gebruiker)] to [$newMailAddress] and/or [userPrincipalName] from [$($currentAccount.Upn)] to [$newUserPrincipalName]\"\r\n                    IsError           = $false\r\n                    TargetDisplayName = $user.userPrincipalName\r\n                    TargetIdentifier  = $user.ObjectGuid\r\n                }\r\n                Write-Information -Tags \"Audit\" -MessageData $log\r\n                break\r\n            }\r\n            \u0027NoChanges\u0027 {\r\n                $Log = @{\r\n                    Action            = \"UpdateAccount\"\r\n                    System            = \"AFAS User\"\r\n                    Message           = \"Successfully checked attributes [EmAd] and [Upn] of AFAS user [$($user.employeeID)]: [EmAd] [$($currentAccount.Email_werk_gebruiker)] equals [$newMailAddress] and [Upn] [$($currentAccount.Upn)] equals [$newUserPrincipalName]; no changes needed\"\r\n                    IsError           = $false\r\n                    TargetDisplayName = $user.userPrincipalName\r\n                    TargetIdentifier  = $user.ObjectGuid\r\n                }\r\n                Write-Information -Tags \"Audit\" -MessageData $log\r\n                break\r\n            }\r\n        }\r\n    }\r\n    catch {\r\n        $ex = $PSItem\r\n        if ($($ex.Exception.GetType().FullName -eq \u0027Microsoft.PowerShell.Commands.HttpResponseException\u0027) -or\r\n            $($ex.Exception.GetType().FullName -eq \u0027System.Net.WebException\u0027)) {\r\n            $errorObj = Resolve-AFAS-ProfitError -ErrorObject $ex\r\n            $warningMessage = \"Error at Line \u0027$($errorObj.ScriptLineNumber)\u0027: $($errorObj.Line). Error: $($errorObj.ErrorDetails)\"\r\n            $auditMessage = \"Error $($actionMessage). Error: $($errorObj.FriendlyMessage)\"\r\n        }\r\n        else {\r\n            $warningMessage = \"Error at Line \u0027$($ex.InvocationInfo.ScriptLineNumber)\u0027: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)\"\r\n            $auditMessage = \"Error $($actionMessage). Error: $($ex.Exception.Message)\"\r\n        }\r\n\r\n        $Log = @{\r\n            Action            = \"UpdateAccount\"\r\n            System            = \"AFAS User\"\r\n            Message           = \"Error $($actionMessage). Error Message: $auditMessage\"\r\n            IsError           = $true\r\n            TargetDisplayName = $user.userPrincipalName\r\n            TargetIdentifier  = $user.ObjectGuid\r\n        }\r\n        Write-Information -Tags \"Audit\" -MessageData $log\r\n        Write-Warning $warningMessage\r\n        Write-Error $auditMessage\r\n    }\r\n}\r\nelse {\r\n    $Log = @{\r\n        Action            = \"UpdateAccount\"\r\n        System            = \"AFAS User\"\r\n        Message           = \"Skipped update attributes [EmAd]/[Upn] of AFAS user [$($user.employeeID)]: employeeID is empty\"\r\n        IsError           = $false\r\n        TargetDisplayName = $user.userPrincipalName\r\n        TargetIdentifier  = $user.ObjectGuid\r\n    }\r\n    Write-Information -Tags \"Audit\" -MessageData $log\r\n}","runInCloud":false}
'@ 

Invoke-HelloIDDelegatedForm -DelegatedFormName $delegatedFormName -DynamicFormGuid $dynamicFormGuid -AccessGroups $delegatedFormAccessGroupGuids -Categories $delegatedFormCategoryGuids -UseFaIcon "True" -FaIcon "fa fa-envelope" -task $tmpTask -returnObject ([Ref]$delegatedFormRef) 
<# End: Delegated Form #>


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

#Global variable #1 >> AFASToken
$tmpName = @'
AFASToken
'@ 
$tmpValue = "" 
$globalHelloIDVariables.Add([PSCustomObject]@{name = $tmpName; value = $tmpValue; secret = "True"});

#Global variable #2 >> AFASBaseUrl
$tmpName = @'
AFASBaseUrl
'@ 
$tmpValue = @'
https://45963.restaccept.afas.online/profitrestservices
'@ 
$globalHelloIDVariables.Add([PSCustomObject]@{name = $tmpName; value = $tmpValue; secret = "False"});

#Global variable #3 >> ADusersSearchOU
$tmpName = @'
ADusersSearchOU
'@ 
$tmpValue = @'
[{ "OU": "OU=HelloID Training,DC=rho003,DC=t4e,DC=com"}]
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
<# Begin: DataSource "AD-AFAS-account-update-upn-email-validate-upn" #>
$tmpPsScript = @'
#######################################################################
# Template: RHo HelloID SA Powershell data source
# Name:     AD-AFAS-account-update-upn-email-validate-upn
# Date:     26-09-2023
#######################################################################

# For basic information about powershell data sources see:
# https://docs.helloid.com/en/service-automation/dynamic-forms/data-sources/powershell-data-sources/add,-edit,-or-remove-a-powershell-data-source.html#add-a-powershell-data-source

# Service automation variables:
# https://docs.helloid.com/en/service-automation/service-automation-variables/service-automation-variable-reference.html

#region init

$VerbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

# global variables (Automation --> Variable libary):
# $globalVar = $globalVarName

# variables configured in form:
$upnPrefix = $datasource.upnPrefix
$upnSuffixCurrent = $datasource.upnSuffixCurrent
$upnSuffixNew = $datasource.upnSuffixNew
$upnSelectedUser = $dataSource.selectedUser.UserPrincipalName

#endregion init

#region functions
function Remove-StringLatinCharacters {
    PARAM ([string]$String)
    [Text.Encoding]::ASCII.GetString([Text.Encoding]::GetEncoding("Cyrillic").GetBytes($String))
}
#endregion functions

#region lookup
try {
    if ([string]::IsNullOrEmpty($upnSuffixNew)) {
        $upn = $upnPrefix + $upnSuffixCurrent
    }
    else {
        $upn = $upnPrefix + $upnSuffixNew
    }

    $upn = Remove-StringLatinCharacters $upn

    # Define a regular expression pattern for a valid UPN
    $pattern = "^[a-zA-Z0-9_%+-]+(\.[a-zA-Z0-9_%+-]+)*@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    
    if ($upn -match $pattern) {
        if ($upnSelectedUser -eq $upn) {
            $returnObject = @{
                text              = "Invalid | UPN [$upnSelectedUser] not changed"
                userPrincipalName = $upn
            }
        }
        else {
            $found = Get-ADUser -Filter { userPrincipalName -eq $upn }
    
            if (@($found).count -eq 0) {
                $returnObject = @{
                    text              = "Valid | UPN [$upn] unique"
                    userPrincipalName = $upn
                }
            }
            else {
                $returnObject = @{
                    text              = "Invalid | UPN [$upn] not unique"
                    userPrincipalName = $upn
                }
            }
            
        }
    }
    else {
        $returnObject = @{
            text              = "Invalid | UPN [$upn] invalid character(s) or pattern"
            userPrincipalName = $upn
        }
    }

    Write-Output $returnObject      

}
catch {
    $ex = $PSItem
    Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        
    Write-Error "Error querying data. Error Message: $($_ex.Exception.Message)" 
}
#endregion lookup
'@ 
$tmpModel = @'
[{"key":"text","type":0},{"key":"userPrincipalName","type":0}]
'@ 
$tmpInput = @'
[{"description":null,"translateDescription":false,"inputFieldType":1,"key":"upnPrefix","type":0,"options":0},{"description":null,"translateDescription":false,"inputFieldType":1,"key":"upnSuffixCurrent","type":0,"options":0},{"description":null,"translateDescription":false,"inputFieldType":1,"key":"upnSuffixNew","type":0,"options":0},{"description":null,"translateDescription":false,"inputFieldType":1,"key":"selectedUser","type":0,"options":0}]
'@ 
$dataSourceGuid_1 = [PSCustomObject]@{} 
$dataSourceGuid_1_Name = @'
AD-AFAS-account-update-upn-email-validate-upn
'@ 
Invoke-HelloIDDatasource -DatasourceName $dataSourceGuid_1_Name -DatasourceType "4" -DatasourceInput $tmpInput -DatasourcePsScript $tmpPsScript -DatasourceModel $tmpModel -returnObject ([Ref]$dataSourceGuid_1) 
<# End: DataSource "AD-AFAS-account-update-upn-email-validate-upn" #>

<# Begin: DataSource "AD-AFAS-account-update-upn-email-lookup-user-generate-table" #>
$tmpPsScript = @'
#######################################################################
# Template: RHo HelloID SA Powershell data source
# Name:     AD-AFAS-account-update-upn-email-lookup-user-generate-table
# Date:     26-09-2023
#######################################################################

# For basic information about powershell data sources see:
# https://docs.helloid.com/en/service-automation/dynamic-forms/data-sources/powershell-data-sources/add,-edit,-or-remove-a-powershell-data-source.html#add-a-powershell-data-source

# Service automation variables:
# https://docs.helloid.com/en/service-automation/service-automation-variables/service-automation-variable-reference.html

#region init

$VerbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

# global variables (Automation --> Variable libary):
$searchOUs = $ADusersSearchOU

# variables configured in form:
$searchValue = $dataSource.searchUser
$searchQuery = "*$searchValue*"

#endregion init

#region functions

#endregion functions

#region lookup
try {
    if ([String]::IsNullOrEmpty($searchValue) -eq $true) {
        return
    }
    else {
        Write-Verbose "SearchQuery: $searchQuery"
        Write-Verbose "SearchBase: $searchOUs"
        
        $ous = $searchOUs | ConvertFrom-Json
        $users = foreach ($item in $ous) {
            Get-ADUser -Filter { Name -like $searchQuery -or userPrincipalName -like $searchQuery -or mail -like $searchQuery } -SearchBase $item.ou -properties displayName, UserPrincipalName, EmailAddress, EmployeeID, GivenName, SurName
        }
    
        # Filter users without employeeID
        $users = $users | Where-Object { $null -ne $_.employeeID }

        $users = $users | Sort-Object -Property DisplayName

        Write-Verbose "Successfully queried data. Result count: $(($users | Measure-Object).Count)"

        if (($users | Measure-Object).Count -gt 0) {
            foreach ($user in $users) {
                # Split UserPrincipalName and EmailAddress for semperate editing
                if (-not([string]::IsNullOrEmpty($user.UserPrincipalName))) {
                    $userPrincipalNameSplit = $($user.UserPrincipalName).Split("@")
                    $userPrincipalNamePrefix = $userPrincipalNameSplit[0]
                    $userPrincipalNameSuffix = "@" + $userPrincipalNameSplit[1]
                }
                if (-not([string]::IsNullOrEmpty($user.EmailAddress))) {
                    $emailAddressSplit = $($user.EmailAddress).Split("@")
                    $emailAddressPrefix = $emailAddressSplit[0]
                    $emailAddressSuffix = "@" + $emailAddressSplit[1]
                }
                $returnObject = @{
                    displayName             = $user.DisplayName
                    UserPrincipalName       = $user.UserPrincipalName
                    EmployeeID              = $user.EmployeeID
                    EmailAddress            = $user.EmailAddress
                    EmailAddressPrefix      = $emailAddressPrefix
                    EmailAddressSuffix      = $emailAddressSuffix
                    UserPrincipalNamePrefix = $userPrincipalNamePrefix
                    UserPrincipalNameSuffix = $userPrincipalNameSuffix
                    GivenName               = $user.GivenName
                    SurName                 = $user.SurName
                }    
                Write-Output $returnObject      
            }
        }
    }
}
catch {
    $ex = $PSItem
    Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        
    Write-Error "Error retrieving AD user [$userPrincipalName] basic attributes. Error: $($_.Exception.Message)"
}
#endregion lookup
'@ 
$tmpModel = @'
[{"key":"UserPrincipalNamePrefix","type":0},{"key":"EmailAddressSuffix","type":0},{"key":"EmployeeID","type":0},{"key":"SurName","type":0},{"key":"UserPrincipalName","type":0},{"key":"GivenName","type":0},{"key":"displayName","type":0},{"key":"EmailAddressPrefix","type":0},{"key":"EmailAddress","type":0},{"key":"UserPrincipalNameSuffix","type":0}]
'@ 
$tmpInput = @'
[{"description":null,"translateDescription":false,"inputFieldType":1,"key":"searchUser","type":0,"options":1}]
'@ 
$dataSourceGuid_0 = [PSCustomObject]@{} 
$dataSourceGuid_0_Name = @'
AD-AFAS-account-update-upn-email-lookup-user-generate-table
'@ 
Invoke-HelloIDDatasource -DatasourceName $dataSourceGuid_0_Name -DatasourceType "4" -DatasourceInput $tmpInput -DatasourcePsScript $tmpPsScript -DatasourceModel $tmpModel -returnObject ([Ref]$dataSourceGuid_0) 
<# End: DataSource "AD-AFAS-account-update-upn-email-lookup-user-generate-table" #>

<# Begin: DataSource "AD-AFAS-account-update-upn-email-validate-email" #>
$tmpPsScript = @'
#######################################################################
# Template: RHo HelloID SA Powershell data source
# Name:     AD-AFAS-account-update-upn-email-validate-email
# Date:     26-09-2023
#######################################################################

# For basic information about powershell data sources see:
# https://docs.helloid.com/en/service-automation/dynamic-forms/data-sources/powershell-data-sources/add,-edit,-or-remove-a-powershell-data-source.html#add-a-powershell-data-source

# Service automation variables:
# https://docs.helloid.com/en/service-automation/service-automation-variables/service-automation-variable-reference.html

#region init

$VerbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

# global variables (Automation --> Variable libary):
# $globalVar = $globalVarName

# variables configured in form:

$emailSelectedUser = $dataSource.selectedUser.EmailAddress
$upnSelectedUser = $dataSource.selectedUser.UserPrincipalName


$upnEmailEqual = $datasource.upnEmailEqual

if ($upnEmailEqual -eq "True") {
    $emailPrefix = $datasource.upnPrefix
    $emailSuffixCurrent = $datasource.upnSuffixCurrent
    $emailSuffixNew = $datasource.upnSuffixNew
}
else {
    $emailPrefix = $datasource.emailPrefix
    $emailSuffixCurrent = $datasource.emailSuffixCurrent
    $emailSuffixNew = $datasource.emailSuffixNew
}

#endregion init

#region functions
function Remove-StringLatinCharacters {
    PARAM ([string]$String)
    [Text.Encoding]::ASCII.GetString([Text.Encoding]::GetEncoding("Cyrillic").GetBytes($String))
}
#endregion functions

#region lookup
try {
    if ([string]::IsNullOrEmpty($emailSuffixNew)) {
        $email = $emailPrefix + $emailSuffixCurrent
    }
    else {
        $email = $emailPrefix + $emailSuffixNew
    }

    $email = Remove-StringLatinCharacters $email

    # Define a regular expression pattern for a valid email
    $pattern = "^[a-zA-Z0-9_%+-]+(\.[a-zA-Z0-9_%+-]+)*@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    
    if ($email -match $pattern) {
        if ($emailSelectedUser -eq $email) {
            $returnObject = @{
                text         = "Invalid | Email [$emailSelectedUser] not changed"
                emailAddress = $email
            }
        }
        else {
            $found = Get-ADUser -Filter { EmailAddress -eq $email }
            if (@($found).count -eq 0) {
                $searchLowerCaseSmtp = "smtp:$email"
                $searchUpperCaseSmtp = "SMTP:$email"
            
                $foundProxyAddresses = Get-ADUser -Filter { ProxyAddresses -eq $searchUpperCaseSmtp -or ProxyAddresses -eq $searchLowerCaseSmtp } -properties UserPrincipalName
                if ((@($foundProxyAddresses).count -gt 0) -and ($upnSelectedUser -ne $foundProxyAddresses.UserPrincipalName)) {
                    $returnObject = @{
                        text         = "Invalid | ProxyAddresses [$email] not unique"
                        emailAddress = $email
                    }
                }
                else {
                    $returnObject = @{
                        text         = "Valid | Email [$email] unique"
                        emailAddress = $email
                    }
                }
            }
            else {
                $returnObject = @{
                    text         = "Invalid | Email [$email] not unique"
                    emailAddress = $email
                }
            }   
        }
    }
    else {
        $returnObject = @{
            text         = "Invalid | Email [$email] invalid character(s) or pattern"
            emailAddress = $email
        }
    }

    Write-Output $returnObject      
}
catch {
    $ex = $PSItem
    Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        
    Write-Error "Error querying data. Error Message: $($_ex.Exception.Message)" 
}
#endregion lookup
'@ 
$tmpModel = @'
[{"key":"text","type":0},{"key":"emailAddress","type":0}]
'@ 
$tmpInput = @'
[{"description":null,"translateDescription":false,"inputFieldType":1,"key":"emailPrefix","type":0,"options":0},{"description":null,"translateDescription":false,"inputFieldType":1,"key":"emailSuffixCurrent","type":0,"options":0},{"description":null,"translateDescription":false,"inputFieldType":1,"key":"emailSuffixNew","type":0,"options":0},{"description":null,"translateDescription":false,"inputFieldType":1,"key":"selectedUser","type":0,"options":0},{"description":null,"translateDescription":false,"inputFieldType":1,"key":"upnPrefix","type":0,"options":0},{"description":null,"translateDescription":false,"inputFieldType":1,"key":"upnSuffixCurrent","type":0,"options":0},{"description":null,"translateDescription":false,"inputFieldType":1,"key":"upnSuffixNew","type":0,"options":0},{"description":null,"translateDescription":false,"inputFieldType":1,"key":"upnEmailEqual","type":0,"options":0}]
'@ 
$dataSourceGuid_2 = [PSCustomObject]@{} 
$dataSourceGuid_2_Name = @'
AD-AFAS-account-update-upn-email-validate-email
'@ 
Invoke-HelloIDDatasource -DatasourceName $dataSourceGuid_2_Name -DatasourceType "4" -DatasourceInput $tmpInput -DatasourcePsScript $tmpPsScript -DatasourceModel $tmpModel -returnObject ([Ref]$dataSourceGuid_2) 
<# End: DataSource "AD-AFAS-account-update-upn-email-validate-email" #>
<# End: HelloID Data sources #>

<# Begin: Dynamic Form "AD AFAS Account - Update UPN - Email" #>
$tmpSchema = @"
[{"label":"Select user account","fields":[{"key":"searchfield","templateOptions":{"label":"Search","placeholder":"Username or Email"},"type":"input","summaryVisibility":"Hide element","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false},{"key":"gridUsers","templateOptions":{"label":"Select user account","required":true,"grid":{"columns":[{"headerName":"Employee ID","field":"EmployeeID"},{"headerName":"Display Name","field":"displayName"},{"headerName":"User Principal Name","field":"UserPrincipalName"},{"headerName":"Email Address","field":"EmailAddress"}],"height":300,"rowSelection":"single"},"dataSourceConfig":{"dataSourceGuid":"$dataSourceGuid_0","input":{"propertyInputs":[{"propertyName":"searchUser","otherFieldValue":{"otherFieldKey":"searchfield"}}]}},"useFilter":false},"type":"grid","summaryVisibility":"Show","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":true}]},{"label":"Details","fields":[{"key":"formRow3","templateOptions":{},"fieldGroup":[{"key":"upnPrefix","templateOptions":{"label":"Current user principal name prefix","useDependOn":true,"dependOn":"gridUsers","dependOnProperty":"UserPrincipalNamePrefix"},"type":"input","summaryVisibility":"Show","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false},{"key":"upnSuffixCurrent","templateOptions":{"label":"Current user principal name suffix","useDependOn":true,"dependOn":"gridUsers","dependOnProperty":"UserPrincipalNameSuffix","readonly":true},"type":"input","summaryVisibility":"Show","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false},{"key":"upnSuffixNew","templateOptions":{"label":"New user principal name suffix","required":false,"useObjects":false,"useDataSource":false,"useFilter":false,"options":["@Option1.com","@Option2.com","@Option3.com"]},"type":"dropdown","summaryVisibility":"Show","textOrLabel":"text","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false}],"type":"formrow","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false},{"key":"validUPN","templateOptions":{"label":"Valid user principal name","required":true,"readonly":true,"useDataSource":true,"dataSourceConfig":{"dataSourceGuid":"$dataSourceGuid_1","input":{"propertyInputs":[{"propertyName":"upnPrefix","otherFieldValue":{"otherFieldKey":"upnPrefix"}},{"propertyName":"upnSuffixCurrent","otherFieldValue":{"otherFieldKey":"upnSuffixCurrent"}},{"propertyName":"upnSuffixNew","otherFieldValue":{"otherFieldKey":"upnSuffixNew"}},{"propertyName":"selectedUser","otherFieldValue":{"otherFieldKey":"gridUsers"}}]}},"displayField":"text","pattern":"^Valid.*","useDependOn":false,"dependOn":"searchfield","minLength":1},"validation":{"messages":{"pattern":"No valid UPN found"}},"type":"input","summaryVisibility":"Show","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false},{"key":"upnEmailEqual","templateOptions":{"label":"User principal name and email have the same value","useSwitch":true,"checkboxLabel":""},"type":"boolean","defaultValue":true,"summaryVisibility":"Show","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false},{"key":"formRow","templateOptions":{},"fieldGroup":[{"key":"emailPrefix","templateOptions":{"label":"Current email prefix","useDependOn":true,"dependOn":"gridUsers","dependOnProperty":"EmailAddressPrefix","readonly":false},"validation":{"messages":{"pattern":""}},"hideExpression":"model[\"upnEmailEqual\"]","type":"input","summaryVisibility":"Show","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false},{"key":"emailSuffixCurrent","templateOptions":{"label":"Current email suffix","useDependOn":true,"dependOn":"gridUsers","dependOnProperty":"EmailAddressSuffix","readonly":true},"validation":{"messages":{"pattern":""}},"hideExpression":"model[\"upnEmailEqual\"]","type":"input","summaryVisibility":"Show","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false},{"key":"emailSuffixNew","templateOptions":{"label":"New email suffix","required":false,"useObjects":false,"useDataSource":false,"useFilter":false,"options":["@Option1.com","@Option2.com","@Option3.com"]},"hideExpression":"model[\"upnEmailEqual\"]","type":"dropdown","summaryVisibility":"Show","textOrLabel":"text","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false}],"type":"formrow","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false},{"key":"validEmail","templateOptions":{"label":"Valid email","readonly":true,"required":true,"pattern":"^Valid.*","useDataSource":true,"dataSourceConfig":{"dataSourceGuid":"$dataSourceGuid_2","input":{"propertyInputs":[{"propertyName":"emailPrefix","otherFieldValue":{"otherFieldKey":"emailPrefix"}},{"propertyName":"emailSuffixCurrent","otherFieldValue":{"otherFieldKey":"emailSuffixCurrent"}},{"propertyName":"emailSuffixNew","otherFieldValue":{"otherFieldKey":"emailSuffixNew"}},{"propertyName":"selectedUser","otherFieldValue":{"otherFieldKey":"gridUsers"}},{"propertyName":"upnPrefix","otherFieldValue":{"otherFieldKey":"upnPrefix"}},{"propertyName":"upnSuffixCurrent","otherFieldValue":{"otherFieldKey":"upnSuffixCurrent"}},{"propertyName":"upnSuffixNew","otherFieldValue":{"otherFieldKey":"upnSuffixNew"}},{"propertyName":"upnEmailEqual","otherFieldValue":{"otherFieldKey":"upnEmailEqual"}}]}},"displayField":"text","minLength":1},"validation":{"messages":{"pattern":"No valid Email found"}},"type":"input","summaryVisibility":"Show","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false}]}]
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
{"name":"AD AFAS Account - Update UPN - Email","script":"#######################################################################\r\n# Template: RHo HelloID SA Delegated form task\r\n# Name:     AD-account-update-upn-email\r\n# Date:     26-09-2023\r\n#######################################################################\r\n\r\n# For basic information about delegated form tasks see:\r\n# https://docs.helloid.com/en/service-automation/delegated-forms/delegated-form-powershell-scripts/add-a-powershell-script-to-a-delegated-form.html\r\n\r\n# Service automation variables:\r\n# https://docs.helloid.com/en/service-automation/service-automation-variables/service-automation-variable-reference.html\r\n\r\n#region init\r\n# Set TLS to accept TLS, TLS 1.1 and TLS 1.2\r\n[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12\r\n\r\n$VerbosePreference = \"SilentlyContinue\"\r\n$InformationPreference = \"Continue\"\r\n$WarningPreference = \"Continue\"\r\n\r\n# global variables (Automation --> Variable libary):\r\n# $globalVar = $globalVarName\r\n\r\n# variables configured in form:\r\n$currentEmail = $form.gridUsers.EmailAddress\r\n$currentUPN = $form.gridUsers.UserPrincipalName\r\n$emailPrefix = $form.emailPrefix\r\n$emailSuffixCurrent = $form.emailSuffixCurrent\r\n$emailSuffixNew = $form.emailSuffixNew\r\n$upnPrefix = $form.upnPrefix\r\n$upnSuffixCurrent = $form.upnSuffixCurrent\r\n$upnSuffixNew = $form.upnSuffixNew\r\n$employeeID = $form.gridUsers.employeeID\r\n$displayName = $form.gridUsers.displayName\r\n$upnEmailEqual = $form.upnEmailEqual\r\n#endregion init\r\n\r\n#region global\r\n\r\nif ([string]::IsNullOrEmpty($upnSuffixNew)) {\r\n    $newUPN = $upnPrefix + $upnSuffixCurrent\r\n}\r\nelse {\r\n    $newUPN = $upnPrefix + $upnSuffixNew\r\n}\r\n\r\nif ($upnEmailEqual -eq \"True\") {\r\n    $newEmail = $newUPN\r\n}\r\nelse {\r\n    if ([string]::IsNullOrEmpty($emailSuffixNew)) {\r\n        $newEmail = $emailPrefix + $emailSuffixCurrent\r\n    }\r\n    else {\r\n        $newEmail = $emailPrefix + $emailSuffixNew\r\n    }\r\n}\r\n\r\n#endregion global\r\n\r\n#region AD\r\n# Search user\r\ntry {\r\n    $properties = @('SID', 'ObjectGuid', 'UserPrincipalName', 'SamAccountName', 'Mail', 'ProxyAddresses', 'EmployeeId')\r\n    $adUser = Get-ADuser -Filter { UserPrincipalName -eq $currentUPN } -Properties $properties\r\n    Write-Information \"Found AD user [$currentUPN]\"        \r\n}\r\ncatch {\r\n    Write-Error \"Could not find AD user [$currentUPN]. Error: $($_.Exception.Message)\"    \r\n}\r\n\r\n# Set UPN\r\ntry {\r\n    Set-ADUser -Identity $adUSer -userprincipalname $newUPN\r\n    \r\n    Write-Information \"Finished update attribute [userprincipalname] of AD user [$($adUser.SID)] from [$currentUPN] to [$newUPN]\"\r\n    $Log = @{\r\n        Action            = \"UpdateAccount\" # optional. ENUM (undefined = default) \r\n        System            = \"ActiveDirectory\" # optional (free format text) \r\n        Message           = \"Successfully updated attribute [userprincipalname] of AD user [$($adUser.SID)] from [$currentUPN] to [$newUPN]\" # required (free format text) \r\n        IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n        TargetDisplayName = $adUser.name # optional (free format text) \r\n        TargetIdentifier  = $([string]$adUser.SID) # optional (free format text) \r\n    }\r\n    #send result back  \r\n    Write-Information -Tags \"Audit\" -MessageData $log    \r\n}\r\ncatch {\r\n    Write-Error \"Could not update attribute [userprincipalname] of AD user [$($adUser.SID)] from [$currentUPN] to [$newUPN]. Error: $($_.Exception.Message)\"\r\n    $Log = @{\r\n        Action            = \"UpdateAccount\" # optional. ENUM (undefined = default) \r\n        System            = \"ActiveDirectory\" # optional (free format text) \r\n        Message           = \"Failed to update attribute [userprincipalname] of AD user [$($adUser.SID)] from [$currentUPN] to [$newUPN]\" # required (free format text) \r\n        IsError           = $true # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n        TargetDisplayName = $adUser.name # optional (free format text) \r\n        TargetIdentifier  = $([string]$adUser.SID) # optional (free format text) \r\n    }\r\n    #send result back  \r\n    Write-Information -Tags \"Audit\" -MessageData $log      \r\n}\r\n\r\n# Set EmailAdress and update proxyAddresses\r\ntry {\r\n    $proxyAddresses = @()\r\n    foreach ($address in $adUSer.ProxyAddresses) {\r\n        if ($address.StartsWith('SMTP:')) {\r\n            $address = $address -replace 'SMTP:', 'smtp:'\r\n        }\r\n        if ($address -eq \"smtp:\" + $newEmail) {\r\n        }\r\n        else {\r\n            $proxyAddresses += $address\r\n        }\r\n    }\r\n\r\n    $newPrimary = 'SMTP:' + $newEmail\r\n    $proxyAddresses += $newPrimary\r\n\r\n    Set-ADUser -Identity $adUSer -emailaddress $newEmail -Replace @{proxyAddresses = $proxyAddresses }\r\n\r\n    Write-Information \"Finished update attribute [emailaddress] of AD user [$($adUser.SID)] from [$currentEmail] to [$newEmail]\"\r\n    $Log = @{\r\n        Action            = \"UpdateAccount\" # optional. ENUM (undefined = default) \r\n        System            = \"ActiveDirectory\" # optional (free format text) \r\n        Message           = \"Successfully updated attribute [emailaddress] of AD user [$($adUser.SID)] from [$currentEmail] to [$newEmail]\" # required (free format text) \r\n        IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n        TargetDisplayName = $adUser.name # optional (free format text) \r\n        TargetIdentifier  = $([string]$adUser.SID) # optional (free format text) \r\n    }\r\n    #send result back  \r\n    Write-Information -Tags \"Audit\" -MessageData $log        \r\n}\r\ncatch {\r\n    Write-Error \"Could not update attribute [emailaddress] of AD user [$($adUser.SID)] from [$currentEmail] to [$newEmail]. Error: $($_.Exception.Message)\"\r\n    $Log = @{\r\n        Action            = \"UpdateAccount\" # optional. ENUM (undefined = default) \r\n        System            = \"ActiveDirectory\" # optional (free format text) \r\n        Message           = \"Failed to update attribute [emailaddress] of AD user [$($adUser.SID)] from [$currentEmail] to [$newEmail]\" # required (free format text) \r\n        IsError           = $true # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n        TargetDisplayName = $adUser.name # optional (free format text) \r\n        TargetIdentifier  = $([string]$adUser.SID) # optional (free format text) \r\n    }\r\n    #send result back  \r\n    Write-Information -Tags \"Audit\" -MessageData $log     \r\n}\r\n#endregion AD\r\n\r\n#region AFAS\r\nfunction Resolve-HTTPError {\r\n    [CmdletBinding()]\r\n    param (\r\n        [Parameter(Mandatory,\r\n            ValueFromPipeline\r\n        )]\r\n        [object]$ErrorObject\r\n    )\r\n    process {\r\n        $httpErrorObj = [PSCustomObject]@{\r\n            FullyQualifiedErrorId = $ErrorObject.FullyQualifiedErrorId\r\n            MyCommand             = $ErrorObject.InvocationInfo.MyCommand\r\n            RequestUri            = $ErrorObject.TargetObject.RequestUri\r\n            ScriptStackTrace      = $ErrorObject.ScriptStackTrace\r\n            ErrorMessage          = ''\r\n        }\r\n        if ($ErrorObject.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') {\r\n            $httpErrorObj.ErrorMessage = $ErrorObject.ErrorDetails.Message\r\n        }\r\n        elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {\r\n            $httpErrorObj.ErrorMessage = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()\r\n        }\r\n        Write-Output $httpErrorObj\r\n    }\r\n}\r\nfunction Resolve-AFASErrorMessage {\r\n    [CmdletBinding()]\r\n    param (\r\n        [Parameter(Mandatory,\r\n            ValueFromPipeline\r\n        )]\r\n        [object]$ErrorObject\r\n    )\r\n    process {\r\n        try {\r\n            $errorObjectConverted = $ErrorObject | ConvertFrom-Json -ErrorAction Stop\r\n\r\n            if ($null -ne $errorObjectConverted.externalMessage) {\r\n                $errorMessage = $errorObjectConverted.externalMessage\r\n            }\r\n            else {\r\n                $errorMessage = $errorObjectConverted\r\n            }\r\n        }\r\n        catch {\r\n            $errorMessage = \"$($ErrorObject.Exception.Message)\"\r\n        }\r\n\r\n        Write-Output $errorMessage\r\n    }\r\n}\r\n\r\n# Used to connect to AFAS API endpoints\r\n$BaseUri = $AFASBaseUrl\r\n$Token = $AFASToken\r\n$getConnector = \"T4E_HelloID_Users_v2\"\r\n$updateConnector = \"KnEmployee\"\r\n\r\n#Change mapping here\r\n$account = [PSCustomObject]@{\r\n    'AfasEmployee' = @{\r\n        'Element' = @{\r\n            'Objects' = @(\r\n                @{\r\n                    'KnPerson' = @{\r\n                        'Element' = @{\r\n                            'Fields' = @{\r\n                                # E-Mail werk  \r\n                                'EmAd' = $newEmail                     \r\n                            }\r\n                        }\r\n                    }\r\n                }\r\n            )\r\n        }\r\n    }\r\n}\r\n\r\n$filterfieldid = \"Medewerker\"\r\n$filtervalue = $employeeID # Has to match the AFAS value of the specified filter field ($filterfieldid)\r\n\r\n# Get current AFAS employee and verify if a user must be either [created], [updated and correlated] or just [correlated]\r\ntry {\r\n    Write-Verbose \"Querying AFAS employee with $($filterfieldid) $($filtervalue)\"\r\n\r\n    # Create authorization headers\r\n    $encodedToken = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($Token))\r\n    $authValue = \"AfasToken $encodedToken\"\r\n    $Headers = @{ Authorization = $authValue }\r\n\r\n    $splatWebRequest = @{\r\n        Uri             = $BaseUri + \"/connectors/\" + $getConnector + \"?filterfieldids=$filterfieldid&filtervalues=$filtervalue&operatortypes=1\"\r\n        Headers         = $headers\r\n        Method          = 'GET'\r\n        ContentType     = \"application/json;charset=utf-8\"\r\n        UseBasicParsing = $true\r\n    }        \r\n    $currentAccount = (Invoke-RestMethod @splatWebRequest -Verbose:$false).rows\r\n\r\n    if ($null -eq $currentAccount.Medewerker) {\r\n        throw \"No AFAS employee found with $($filterfieldid) $($filtervalue)\"\r\n    }\r\n    Write-Information \"Found AFAS employee [$($currentAccount.Medewerker)]\"\r\n    # Check if current EmAd has a different value from mapped value. AFAS will throw an error when trying to update this with the same value\r\n    if ([string]$currentAccount.Email_werk -ne $account.'AfasEmployee'.'Element'.Objects[0].'KnPerson'.'Element'.'Fields'.'EmAd' -and $null -ne $account.'AfasEmployee'.'Element'.Objects[0].'KnPerson'.'Element'.'Fields'.'EmAd') {\r\n        $propertiesChanged += @('EmAd')\r\n    }\r\n    if ($propertiesChanged) {\r\n        Write-Verbose \"Account property(s) required to update: [$($propertiesChanged -join \",\")]\"\r\n        $updateAction = 'Update'\r\n    }\r\n    else {\r\n        $updateAction = 'NoChanges'\r\n    }\r\n\r\n    # Update AFAS Employee\r\n    Write-Verbose \"Start updating AFAS employee [$($currentAccount.Medewerker)]\"\r\n    switch ($updateAction) {\r\n        'Update' {\r\n            # Create custom account object for update\r\n            $updateAccount = [PSCustomObject]@{\r\n                'AfasEmployee' = @{\r\n                    'Element' = @{\r\n                        '@EmId'   = $currentAccount.Medewerker\r\n                        'Objects' = @(@{\r\n                                'KnPerson' = @{\r\n                                    'Element' = @{\r\n                                        'Fields' = @{\r\n                                            # Zoek op BcCo (Persoons-ID)\r\n                                            'MatchPer' = 0\r\n                                            # Nummer\r\n                                            'BcCo'     = $currentAccount.Persoonsnummer\r\n                                        }\r\n                                    }\r\n                                }\r\n                            })\r\n                    }\r\n                }\r\n            }\r\n            if ('EmAd' -in $propertiesChanged) {\r\n                # E-mail werk\r\n                $updateAccount.'AfasEmployee'.'Element'.Objects[0].'KnPerson'.'Element'.'Fields'.'EmAd' = $account.'AfasEmployee'.'Element'.Objects[0].'KnPerson'.'Element'.'Fields'.'EmAd'\r\n                Write-Information \"Updating BusinessEmailAddress '$($currentAccount.Email_werk)' with new value '$($updateAccount.'AfasEmployee'.'Element'.Objects[0].'KnPerson'.'Element'.'Fields'.'EmAd')'\"\r\n            }\r\n\r\n            $body = ($updateAccount | ConvertTo-Json -Depth 10)\r\n            $splatWebRequest = @{\r\n                Uri             = $BaseUri + \"/connectors/\" + $updateConnector\r\n                Headers         = $headers\r\n                Method          = 'PUT'\r\n                Body            = ([System.Text.Encoding]::UTF8.GetBytes($body))\r\n                ContentType     = \"application/json;charset=utf-8\"\r\n                UseBasicParsing = $true\r\n            }\r\n\r\n            $updatedAccount = Invoke-RestMethod @splatWebRequest -Verbose:$false\r\n            Write-Information \"Successfully updated attribute [EmAd] of AFAS emplyee [$employeeID] from [$($currentAccount.Email_werk)] to [$newEmail]\"\r\n            $Log = @{\r\n                Action            = \"UpdateAccount\" # optional. ENUM (undefined = default) \r\n                System            = \"AFAS Employee\" # optional (free format text) \r\n                Message           = \"Successfully updated attribute [EmAd] of AFAS emplyee [$employeeID] from [$($currentAccount.Email_werk)] to [$newEmail]\" # required (free format text) \r\n                IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n                TargetDisplayName = $displayName # optional (free format text) \r\n                TargetIdentifier  = $([string]$employeeID) # optional (free format text) \r\n            }\r\n            #send result back  \r\n            Write-Information -Tags \"Audit\" -MessageData $log  \r\n            break\r\n        }\r\n        'NoChanges' {\r\n            Write-Information \"Successfully checked attribute [EmAd] of AFAS emplyee [$employeeID] from [$($currentAccount.Email_werk)] to [$newEmail], no changes needed\"\r\n            $Log = @{\r\n                Action            = \"UpdateAccount\" # optional. ENUM (undefined = default) \r\n                System            = \"AFAS Employee\" # optional (free format text) \r\n                Message           = \"Successfully checked attribute [EmAd] of AFAS emplyee [$employeeID] from [$($currentAccount.Email_werk)] to [$newEmail], no changes needed\" # required (free format text) \r\n                IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n                TargetDisplayName = $displayName # optional (free format text) \r\n                TargetIdentifier  = $([string]$employeeID) # optional (free format text) \r\n            }\r\n            #send result back  \r\n            Write-Information -Tags \"Audit\" -MessageData $log  \r\n            break\r\n        }\r\n    }\r\n}\r\ncatch {\r\n    $ex = $PSItem\r\n    if ( $($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {\r\n        $errorObject = Resolve-HTTPError -Error $ex\r\n\r\n        $verboseErrorMessage = $errorObject.ErrorMessage\r\n\r\n        $auditErrorMessage = Resolve-AFASErrorMessage -ErrorObject $errorObject.ErrorMessage\r\n    }\r\n\r\n    # If error message empty, fall back on $ex.Exception.Message\r\n    if ([String]::IsNullOrEmpty($verboseErrorMessage)) {\r\n        $verboseErrorMessage = $ex.Exception.Message\r\n    }\r\n    if ([String]::IsNullOrEmpty($auditErrorMessage)) {\r\n        $auditErrorMessage = $ex.Exception.Message\r\n    }\r\n\r\n    $ex = $PSItem\r\n    $verboseErrorMessage = $ex\r\n    if ($auditErrorMessage -Like \"No AFAS employee found with $($filterfieldid) $($filtervalue)\") {\r\n        Write-Information \"Skipped update attribute [EmAd] of AFAS emplyee [$employeeID] to [$newEmail]: No AFAS employee found with $($filterfieldid) $($filtervalue)\"\r\n        $Log = @{\r\n            Action            = \"UpdateAccount\" # optional. ENUM (undefined = default) \r\n            System            = \"AFAS Employee\" # optional (free format text) \r\n            Message           = \"Skipped update attribute [EmAd] of AFAS employee [$employeeID] to [$newEmail]: No AFAS employee found with $($filterfieldid) $($filtervalue)\" # required (free format text) \r\n            IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n            TargetDisplayName = $displayName # optional (free format text) \r\n            TargetIdentifier  = $([string]$employeeID) # optional (free format text)\r\n        }\r\n        #send result back  \r\n        Write-Information -Tags \"Audit\" -MessageData $log \r\n    }\r\n    else {\r\n        Write-Verbose \"Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($verboseErrorMessage)\"\r\n        Write-Error \"Error updating AFAS employee $($currentAccount.Medewerker). Error Message: $auditErrorMessage\"\r\n        Write-Information \"Error updating AFAS employee $($currentAccount.Medewerker). Error Message: $auditErrorMessage\"\r\n        $Log = @{\r\n            Action            = \"UpdateAccount\" # optional. ENUM (undefined = default) \r\n            System            = \"AFAS Employee\" # optional (free format text) \r\n            Message           = \"Error updating AFAS employee $($currentAccount.Medewerker). Error Message: $auditErrorMessage\" # required (free format text) \r\n            IsError           = $true # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n            TargetDisplayName = $displayName # optional (free format text) \r\n            TargetIdentifier  = $([string]$employeeID) # optional (free format text) \r\n        }\r\n        #send result back  \r\n        Write-Information -Tags \"Audit\" -MessageData $log \r\n    }\r\n}\r\n#endregion AFAS","runInCloud":false}
'@ 

Invoke-HelloIDDelegatedForm -DelegatedFormName $delegatedFormName -DynamicFormGuid $dynamicFormGuid -AccessGroups $delegatedFormAccessGroupGuids -Categories $delegatedFormCategoryGuids -UseFaIcon "True" -FaIcon "fa fa-envelope" -task $tmpTask -returnObject ([Ref]$delegatedFormRef) 
<# End: Delegated Form #>


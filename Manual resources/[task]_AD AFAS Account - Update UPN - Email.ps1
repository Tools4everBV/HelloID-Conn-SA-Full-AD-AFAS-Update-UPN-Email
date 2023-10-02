#######################################################################
# Template: RHo HelloID SA Delegated form task
# Name:     AD-account-update-upn-email
# Date:     26-09-2023
#######################################################################

# For basic information about delegated form tasks see:
# https://docs.helloid.com/en/service-automation/delegated-forms/delegated-form-powershell-scripts/add-a-powershell-script-to-a-delegated-form.html

# Service automation variables:
# https://docs.helloid.com/en/service-automation/service-automation-variables/service-automation-variable-reference.html

#region init
# Set TLS to accept TLS, TLS 1.1 and TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

$VerbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

# global variables (Automation --> Variable libary):
# $globalVar = $globalVarName

# variables configured in form:
$currentEmail = $form.gridUsers.EmailAddress
$currentUPN = $form.gridUsers.UserPrincipalName
$emailPrefix = $form.emailPrefix
$emailSuffixCurrent = $form.emailSuffixCurrent
$emailSuffixNew = $form.emailSuffixNew
$upnPrefix = $form.upnPrefix
$upnSuffixCurrent = $form.upnSuffixCurrent
$upnSuffixNew = $form.upnSuffixNew
$employeeID = $form.gridUsers.employeeID
$displayName = $form.gridUsers.displayName
$upnEmailEqual = $form.upnEmailEqual
#endregion init

#region global

if ([string]::IsNullOrEmpty($upnSuffixNew)) {
    $newUPN = $upnPrefix + $upnSuffixCurrent
}
else {
    $newUPN = $upnPrefix + $upnSuffixNew
}

if ($upnEmailEqual -eq "True") {
    $newEmail = $newUPN
}
else {
    if ([string]::IsNullOrEmpty($emailSuffixNew)) {
        $newEmail = $emailPrefix + $emailSuffixCurrent
    }
    else {
        $newEmail = $emailPrefix + $emailSuffixNew
    }
}

#endregion global

#region AD
# Search user
try {
    $properties = @('SID', 'ObjectGuid', 'UserPrincipalName', 'SamAccountName', 'Mail', 'ProxyAddresses', 'EmployeeId')
    $adUser = Get-ADuser -Filter { UserPrincipalName -eq $currentUPN } -Properties $properties
    Write-Information "Found AD user [$currentUPN]"        
}
catch {
    Write-Error "Could not find AD user [$currentUPN]. Error: $($_.Exception.Message)"    
}

# Set UPN
try {
    Set-ADUser -Identity $adUSer -userprincipalname $newUPN
    
    Write-Information "Finished update attribute [userprincipalname] of AD user [$($adUser.SID)] from [$currentUPN] to [$newUPN]"
    $Log = @{
        Action            = "UpdateAccount" # optional. ENUM (undefined = default) 
        System            = "ActiveDirectory" # optional (free format text) 
        Message           = "Successfully updated attribute [userprincipalname] of AD user [$($adUser.SID)] from [$currentUPN] to [$newUPN]" # required (free format text) 
        IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) 
        TargetDisplayName = $adUser.name # optional (free format text) 
        TargetIdentifier  = $([string]$adUser.SID) # optional (free format text) 
    }
    #send result back  
    Write-Information -Tags "Audit" -MessageData $log    
}
catch {
    Write-Error "Could not update attribute [userprincipalname] of AD user [$($adUser.SID)] from [$currentUPN] to [$newUPN]. Error: $($_.Exception.Message)"
    $Log = @{
        Action            = "UpdateAccount" # optional. ENUM (undefined = default) 
        System            = "ActiveDirectory" # optional (free format text) 
        Message           = "Failed to update attribute [userprincipalname] of AD user [$($adUser.SID)] from [$currentUPN] to [$newUPN]" # required (free format text) 
        IsError           = $true # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) 
        TargetDisplayName = $adUser.name # optional (free format text) 
        TargetIdentifier  = $([string]$adUser.SID) # optional (free format text) 
    }
    #send result back  
    Write-Information -Tags "Audit" -MessageData $log      
}

# Set EmailAdress and update proxyAddresses
try {
    $proxyAddresses = @()
    foreach ($address in $adUSer.ProxyAddresses) {
        if ($address.StartsWith('SMTP:')) {
            $address = $address -replace 'SMTP:', 'smtp:'
        }
        if ($address -eq "smtp:" + $newEmail) {
        }
        else {
            $proxyAddresses += $address
        }
    }

    $newPrimary = 'SMTP:' + $newEmail
    $proxyAddresses += $newPrimary

    Set-ADUser -Identity $adUSer -emailaddress $newEmail -Replace @{proxyAddresses = $proxyAddresses }

    Write-Information "Finished update attribute [emailaddress] of AD user [$($adUser.SID)] from [$currentEmail] to [$newEmail]"
    $Log = @{
        Action            = "UpdateAccount" # optional. ENUM (undefined = default) 
        System            = "ActiveDirectory" # optional (free format text) 
        Message           = "Successfully updated attribute [emailaddress] of AD user [$($adUser.SID)] from [$currentEmail] to [$newEmail]" # required (free format text) 
        IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) 
        TargetDisplayName = $adUser.name # optional (free format text) 
        TargetIdentifier  = $([string]$adUser.SID) # optional (free format text) 
    }
    #send result back  
    Write-Information -Tags "Audit" -MessageData $log        
}
catch {
    Write-Error "Could not update attribute [emailaddress] of AD user [$($adUser.SID)] from [$currentEmail] to [$newEmail]. Error: $($_.Exception.Message)"
    $Log = @{
        Action            = "UpdateAccount" # optional. ENUM (undefined = default) 
        System            = "ActiveDirectory" # optional (free format text) 
        Message           = "Failed to update attribute [emailaddress] of AD user [$($adUser.SID)] from [$currentEmail] to [$newEmail]" # required (free format text) 
        IsError           = $true # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) 
        TargetDisplayName = $adUser.name # optional (free format text) 
        TargetIdentifier  = $([string]$adUser.SID) # optional (free format text) 
    }
    #send result back  
    Write-Information -Tags "Audit" -MessageData $log     
}
#endregion AD

#region AFAS
function Resolve-HTTPError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
            ValueFromPipeline
        )]
        [object]$ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            FullyQualifiedErrorId = $ErrorObject.FullyQualifiedErrorId
            MyCommand             = $ErrorObject.InvocationInfo.MyCommand
            RequestUri            = $ErrorObject.TargetObject.RequestUri
            ScriptStackTrace      = $ErrorObject.ScriptStackTrace
            ErrorMessage          = ''
        }
        if ($ErrorObject.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') {
            $httpErrorObj.ErrorMessage = $ErrorObject.ErrorDetails.Message
        }
        elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            $httpErrorObj.ErrorMessage = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
        }
        Write-Output $httpErrorObj
    }
}
function Resolve-AFASErrorMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
            ValueFromPipeline
        )]
        [object]$ErrorObject
    )
    process {
        try {
            $errorObjectConverted = $ErrorObject | ConvertFrom-Json -ErrorAction Stop

            if ($null -ne $errorObjectConverted.externalMessage) {
                $errorMessage = $errorObjectConverted.externalMessage
            }
            else {
                $errorMessage = $errorObjectConverted
            }
        }
        catch {
            $errorMessage = "$($ErrorObject.Exception.Message)"
        }

        Write-Output $errorMessage
    }
}

# Used to connect to AFAS API endpoints
$BaseUri = $AFASBaseUrl
$Token = $AFASToken
$getConnector = "T4E_HelloID_Users_v2"
$updateConnector = "KnEmployee"

#Change mapping here
$account = [PSCustomObject]@{
    'AfasEmployee' = @{
        'Element' = @{
            'Objects' = @(
                @{
                    'KnPerson' = @{
                        'Element' = @{
                            'Fields' = @{
                                # E-Mail werk  
                                'EmAd' = $newEmail                     
                            }
                        }
                    }
                }
            )
        }
    }
}

$filterfieldid = "Medewerker"
$filtervalue = $employeeID # Has to match the AFAS value of the specified filter field ($filterfieldid)

# Get current AFAS employee and verify if a user must be either [created], [updated and correlated] or just [correlated]
try {
    Write-Verbose "Querying AFAS employee with $($filterfieldid) $($filtervalue)"

    # Create authorization headers
    $encodedToken = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($Token))
    $authValue = "AfasToken $encodedToken"
    $Headers = @{ Authorization = $authValue }

    $splatWebRequest = @{
        Uri             = $BaseUri + "/connectors/" + $getConnector + "?filterfieldids=$filterfieldid&filtervalues=$filtervalue&operatortypes=1"
        Headers         = $headers
        Method          = 'GET'
        ContentType     = "application/json;charset=utf-8"
        UseBasicParsing = $true
    }        
    $currentAccount = (Invoke-RestMethod @splatWebRequest -Verbose:$false).rows

    if ($null -eq $currentAccount.Medewerker) {
        throw "No AFAS employee found with $($filterfieldid) $($filtervalue)"
    }
    Write-Information "Found AFAS employee [$($currentAccount.Medewerker)]"
    # Check if current EmAd has a different value from mapped value. AFAS will throw an error when trying to update this with the same value
    if ([string]$currentAccount.Email_werk -ne $account.'AfasEmployee'.'Element'.Objects[0].'KnPerson'.'Element'.'Fields'.'EmAd' -and $null -ne $account.'AfasEmployee'.'Element'.Objects[0].'KnPerson'.'Element'.'Fields'.'EmAd') {
        $propertiesChanged += @('EmAd')
    }
    if ($propertiesChanged) {
        Write-Verbose "Account property(s) required to update: [$($propertiesChanged -join ",")]"
        $updateAction = 'Update'
    }
    else {
        $updateAction = 'NoChanges'
    }

    # Update AFAS Employee
    Write-Verbose "Start updating AFAS employee [$($currentAccount.Medewerker)]"
    switch ($updateAction) {
        'Update' {
            # Create custom account object for update
            $updateAccount = [PSCustomObject]@{
                'AfasEmployee' = @{
                    'Element' = @{
                        '@EmId'   = $currentAccount.Medewerker
                        'Objects' = @(@{
                                'KnPerson' = @{
                                    'Element' = @{
                                        'Fields' = @{
                                            # Zoek op BcCo (Persoons-ID)
                                            'MatchPer' = 0
                                            # Nummer
                                            'BcCo'     = $currentAccount.Persoonsnummer
                                        }
                                    }
                                }
                            })
                    }
                }
            }
            if ('EmAd' -in $propertiesChanged) {
                # E-mail werk
                $updateAccount.'AfasEmployee'.'Element'.Objects[0].'KnPerson'.'Element'.'Fields'.'EmAd' = $account.'AfasEmployee'.'Element'.Objects[0].'KnPerson'.'Element'.'Fields'.'EmAd'
                Write-Information "Updating BusinessEmailAddress '$($currentAccount.Email_werk)' with new value '$($updateAccount.'AfasEmployee'.'Element'.Objects[0].'KnPerson'.'Element'.'Fields'.'EmAd')'"
            }

            $body = ($updateAccount | ConvertTo-Json -Depth 10)
            $splatWebRequest = @{
                Uri             = $BaseUri + "/connectors/" + $updateConnector
                Headers         = $headers
                Method          = 'PUT'
                Body            = ([System.Text.Encoding]::UTF8.GetBytes($body))
                ContentType     = "application/json;charset=utf-8"
                UseBasicParsing = $true
            }

            $updatedAccount = Invoke-RestMethod @splatWebRequest -Verbose:$false
            Write-Information "Successfully updated attribute [EmAd] of AFAS emplyee [$employeeID] from [$($currentAccount.Email_werk)] to [$newEmail]"
            $Log = @{
                Action            = "UpdateAccount" # optional. ENUM (undefined = default) 
                System            = "AFAS Employee" # optional (free format text) 
                Message           = "Successfully updated attribute [EmAd] of AFAS emplyee [$employeeID] from [$($currentAccount.Email_werk)] to [$newEmail]" # required (free format text) 
                IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) 
                TargetDisplayName = $displayName # optional (free format text) 
                TargetIdentifier  = $([string]$employeeID) # optional (free format text) 
            }
            #send result back  
            Write-Information -Tags "Audit" -MessageData $log  
            break
        }
        'NoChanges' {
            Write-Information "Successfully checked attribute [EmAd] of AFAS emplyee [$employeeID] from [$($currentAccount.Email_werk)] to [$newEmail], no changes needed"
            $Log = @{
                Action            = "UpdateAccount" # optional. ENUM (undefined = default) 
                System            = "AFAS Employee" # optional (free format text) 
                Message           = "Successfully checked attribute [EmAd] of AFAS emplyee [$employeeID] from [$($currentAccount.Email_werk)] to [$newEmail], no changes needed" # required (free format text) 
                IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) 
                TargetDisplayName = $displayName # optional (free format text) 
                TargetIdentifier  = $([string]$employeeID) # optional (free format text) 
            }
            #send result back  
            Write-Information -Tags "Audit" -MessageData $log  
            break
        }
    }
}
catch {
    $ex = $PSItem
    if ( $($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObject = Resolve-HTTPError -Error $ex

        $verboseErrorMessage = $errorObject.ErrorMessage

        $auditErrorMessage = Resolve-AFASErrorMessage -ErrorObject $errorObject.ErrorMessage
    }

    # If error message empty, fall back on $ex.Exception.Message
    if ([String]::IsNullOrEmpty($verboseErrorMessage)) {
        $verboseErrorMessage = $ex.Exception.Message
    }
    if ([String]::IsNullOrEmpty($auditErrorMessage)) {
        $auditErrorMessage = $ex.Exception.Message
    }

    $ex = $PSItem
    $verboseErrorMessage = $ex
    if ($auditErrorMessage -Like "No AFAS employee found with $($filterfieldid) $($filtervalue)") {
        Write-Information "Skipped update attribute [EmAd] of AFAS emplyee [$employeeID] to [$newEmail]: No AFAS employee found with $($filterfieldid) $($filtervalue)"
        $Log = @{
            Action            = "UpdateAccount" # optional. ENUM (undefined = default) 
            System            = "AFAS Employee" # optional (free format text) 
            Message           = "Skipped update attribute [EmAd] of AFAS employee [$employeeID] to [$newEmail]: No AFAS employee found with $($filterfieldid) $($filtervalue)" # required (free format text) 
            IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) 
            TargetDisplayName = $displayName # optional (free format text) 
            TargetIdentifier  = $([string]$employeeID) # optional (free format text)
        }
        #send result back  
        Write-Information -Tags "Audit" -MessageData $log 
    }
    else {
        Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($verboseErrorMessage)"
        Write-Error "Error updating AFAS employee $($currentAccount.Medewerker). Error Message: $auditErrorMessage"
        Write-Information "Error updating AFAS employee $($currentAccount.Medewerker). Error Message: $auditErrorMessage"
        $Log = @{
            Action            = "UpdateAccount" # optional. ENUM (undefined = default) 
            System            = "AFAS Employee" # optional (free format text) 
            Message           = "Error updating AFAS employee $($currentAccount.Medewerker). Error Message: $auditErrorMessage" # required (free format text) 
            IsError           = $true # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) 
            TargetDisplayName = $displayName # optional (free format text) 
            TargetIdentifier  = $([string]$employeeID) # optional (free format text) 
        }
        #send result back  
        Write-Information -Tags "Audit" -MessageData $log 
    }
}
#endregion AFAS

# variables configured in form:
$user = $form.gridUsers
$blnmail = [System.Convert]::ToBoolean($form.blnMail)
$blnupn = [System.Convert]::ToBoolean($form.blnUPN)
$newMailAddress = $form.newMail
$newUserPrincipalName = $form.newUPN
$BaseUri = $AFASBaseUrl
$Token = $AFASToken
$getConnector = "T4E_HelloID_Users_v2"
$updateConnector = "KnEmployee"
$filterfieldid = "Medewerker"
$filtervalue = $user.employeeID # Has to match the AFAS value of the specified filter field ($filterfieldid)

# Set debug logging
$VerbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

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
        [Parameter(ValueFromPipeline)]
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

try {
    $actionMessage = "updating AD attributes for user [$($user.userPrincipalName)] with objectguid [$($user.ObjectGuid)]"

    $proxyAddresses = @()
    foreach ($address in $user.ProxyAddresses) {
        if ($address.StartsWith('SMTP:')) {
            $address = $address -replace 'SMTP:', 'smtp:'
        }
        if ($address -eq "smtp:" + $newMailAddress) {
        }
        else {
            $proxyAddresses += $address
        }
    }

    $newPrimary = 'SMTP:' + $newMailAddress
    $proxyAddresses += $newPrimary

    if ($blnupn -eq $true) {
        Set-ADUser -Identity $user.ObjectGuid -userprincipalname $newUserPrincipalName 

        $Log = @{
            Action            = "UpdateAccount" # optional. ENUM (undefined = default) 
            System            = "ActiveDirectory" # optional (free format text) 
            Message           = "Successfully updated AD user [$($user.userPrincipalName)] attributes [userPrincipalName] from [$($user.userPrincipalName)] to [$newUserPrincipalName]" # required (free format text) 
            IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) 
            TargetDisplayName = $user.userPrincipalName # optional (free format text) 
            TargetIdentifier  = $user.ObjectGuid # optional (free format text) 
        }
        #send result back  
        Write-Information -Tags "Audit" -MessageData $log     
    }

    if ($blnmail -eq $true) {
        Set-ADUser -Identity $user.ObjectGuid -emailaddress $newMailAddress -Replace @{proxyAddresses = $proxyAddresses }

        $Log = @{
            Action            = "UpdateAccount" # optional. ENUM (undefined = default) 
            System            = "ActiveDirectory" # optional (free format text) 
            Message           = "Successfully updated AD user [$($user.mail)] attributes [mail] from [$($user.mail)] to [$newMailAddress]" # required (free format text) 
            IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) 
            TargetDisplayName = $user.userPrincipalName # optional (free format text) 
            TargetIdentifier  = $user.ObjectGuid # optional (free format text) 
        }
        #send result back  
        Write-Information -Tags "Audit" -MessageData $log     
    }
}
catch {
    $ex = $PSItem
    $auditMessage = "Error $($actionMessage). Error: $($ex.Exception.Message)"
    $warningMessage = "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"  

    $Log = @{
        Action            = "UpdateAccount" # optional. ENUM (undefined = default) 
        System            = "ActiveDirectory" # optional (free format text) 
        Message           = "Failed to update AD user [$($user.userPrincipalName)] attributes [userPrincipalName] from [$($user.userPrincipalName)] to [$newUserPrincipalName], [emailaddress] from [$($user.mail)] to [$newMailAddress]" # required (free format text) 
        IsError           = $true # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) 
        TargetDisplayName = $user.userPrincipalName # optional (free format text) 
        TargetIdentifier  = $user.ObjectGuid # optional (free format text) 
    }
    #send result back  
    Write-Information -Tags "Audit" -MessageData $log      
    Write-Warning $warningMessage   
    Write-Error $auditMessage   
}
#endregion AD

#region AFAS
#AFAS Employee
if (-not([string]::IsNullOrEmpty($user.employeeID))) {
    # Used to connect to AFAS API endpoints

    #Change mapping here
    $accountEmployee = [PSCustomObject]@{
        'AfasEmployee' = @{
            'Element' = @{
                'Objects' = @(
                    @{
                        'KnPerson' = @{
                            'Element' = @{
                                'Fields' = @{
                                    # E-Mail werk  
                                    'EmAd' = $newMailAddress
                                }
                            }
                        }
                    }
                )
            }
        }
    }

    #$filterfieldid = "Medewerker"
    #$filtervalue = $user.employeeID # Has to match the AFAS value of the specified filter field ($filterfieldid)

    # Get current AFAS employee and verify if a user must be either [created], [updated and correlated] or just [correlated]
    try {
        $actionMessage = "Querying AFAS employee with $($filterfieldid) $($filtervalue)"

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
        # Check if current EmAd has a different value from mapped value. AFAS will throw an error when trying to update this with the same value
        if ([string]$currentAccount.Email_werk -ne $accountEmployee.'AfasEmployee'.'Element'.Objects[0].'KnPerson'.'Element'.'Fields'.'EmAd' -and $null -ne $accountEmployee.'AfasEmployee'.'Element'.Objects[0].'KnPerson'.'Element'.'Fields'.'EmAd') {
            $propertiesChanged += @('EmAd')
        }

        if ($propertiesChanged) {
            $updateAction = 'Update'
        }
        else {
            $updateAction = 'NoChanges'
        }

        # Update AFAS Employee
        switch ($updateAction) {
            'Update' {
                $actionmessage = "updating AFAS employee [$($user.EmployeeID)] attributes [EmAd] from [$($currentAccount.Email_werk)] to [$newMailAddress] and/or [Upn] from [$($currentAccount.Upn)] to [$newUserPrincipalName]."
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
                    $updateAccount.'AfasEmployee'.'Element'.Objects[0].'KnPerson'.'Element'.'Fields'.'EmAd' = $accountEmployee.'AfasEmployee'.'Element'.Objects[0].'KnPerson'.'Element'.'Fields'.'EmAd'

                    $body = ($updateAccount | ConvertTo-Json -Depth 10)
                    $splatWebRequest = @{
                        Uri             = $BaseUri + "/connectors/" + $updateConnector
                        Headers         = $headers
                        Method          = 'PUT'
                        Body            = ([System.Text.Encoding]::UTF8.GetBytes($body))
                        ContentType     = "application/json;charset=utf-8"
                        UseBasicParsing = $true
                    }

                    Invoke-RestMethod @splatWebRequest -Verbose:$false
                    $Log = @{
                        Action            = "UpdateAccount" # optional. ENUM (undefined = default) 
                        System            = "AFAS Employee" # optional (free format text) 
                        Message           = "Successfully updated attribute [EmAd] of AFAS employee [$($user.employeeID)] from [$($currentAccount.Email_werk)] to [$newMailAddress]" # required (free format text) 
                        IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) 
                        TargetDisplayName = $user.userPrincipalName # optional (free format text) 
                        TargetIdentifier  = $user.ObjectGuid # optional (free format text) 
                    }
                    #send result back  
                    Write-Information -Tags "Audit" -MessageData $log  
                }

                break
            }
            'NoChanges' {
                $Log = @{
                    Action            = "UpdateAccount" # optional. ENUM (undefined = default) 
                    System            = "AFAS Employee" # optional (free format text) 
                    Message           = "Successfully checked attributes [EmAd] and [Upn] of AFAS employee [$($user.employeeID)]: [EmAd] [$($currentAccount.Email_werk)] equals [$newMailAddress] and [Upn] [$($currentAccount.Upn)] equals [$newUserPrincipalName]; no changes needed" # required (free format text) 
                    IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) 
                    TargetDisplayName = $user.userPrincipalName # optional (free format text) 
                    TargetIdentifier  = $user.ObjectGuid # optional (free format text) 
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
        $auditMessage = "Error $($actionMessage). Error: $($ex.Exception.Message)"
        $warningMessage = "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"

        $Log = @{
            Action            = "UpdateAccount" # optional. ENUM (undefined = default) 
            System            = "AFAS Employee" # optional (free format text) 
            Message           = "Error $($actionMessage). Error Message: $auditErrorMessage" # required (free format text) 
            IsError           = $true # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) 
            TargetDisplayName = $user.userPrincipalName # optional (free format text) 
            TargetIdentifier  = $user.ObjectGuid # optional (free format text) 
        }
        #send result back  
        Write-Information -Tags "Audit" -MessageData $log
        Write-Warning $warningMessage   
        Write-Error $auditMessage
    }
}
else {
    $Log = @{
        Action            = "UpdateAccount" # optional. ENUM (undefined = default) 
        System            = "AFAS Employee" # optional (free format text) 
        Message           = "Skipped update attributes [EmAd] to [$newMailAddress] of AFAS employee [$($user.employeeID)]: employeeID is empty" # required (free format text) 
        IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) 
        TargetDisplayName = $user.userPrincipalName # optional (free format text) 
        TargetIdentifier  = $user.ObjectGuid # optional (free format text)
    }
    #send result back  
    Write-Information -Tags "Audit" -MessageData $log 
}

#AFAS User
if (-not([string]::IsNullOrEmpty($user.employeeID))) {
    # Used to connect to AFAS API endpoints
    try {
        $actionMessage = "Querying AFAS employee with $($filterfieldid) $($filtervalue)"

        # Create authorization headers
        $encodedToken = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($Token))
        $authValue = "AfasToken $encodedToken"
        $Headers = @{ Authorization = $authValue }

        $splatWebRequest = @{
            Uri             = $BaseUri + "/connectors/" + $getConnector + "?filterfieldids=$filterfieldid&filtervalues=$filtervalue&operatortypes=1"
            Headers         = $Headers
            Method          = 'GET'
            ContentType     = "application/json;charset=utf-8"
            UseBasicParsing = $true
        }
        $currentAccount = (Invoke-RestMethod @splatWebRequest -Verbose:$false).rows

        if ($null -eq $currentAccount.Medewerker) {
            throw "No AFAS employee found with $($filterfieldid) $($filtervalue)"
        }

        $propertiesChanged = @()

        if (-not [string]::IsNullOrEmpty($newMailAddress) -and [string]$currentAccount.Email_werk_gebruiker -ne $newMailAddress) {
            $propertiesChanged += @('EmAd')
        }
        if (-not [string]::IsNullOrEmpty($newUserPrincipalName) -and [string]$currentAccount.Upn -ne $newUserPrincipalName) {
            $propertiesChanged += @('Upn')
        }

        if ($propertiesChanged) {
            $updateAction = 'Update'
        }
        else {
            $updateAction = 'NoChanges'
        }

        # Update AFAS User
        switch ($updateAction) {
            'Update' {
                $actionmessage = "updating AFAS user [$($user.EmployeeID)] attributes [EmAd] from [$($currentAccount.Email_werk_gebruiker)] to [$newMailAddress] and/or [Upn] from [$($currentAccount.Upn)] to [$newUserPrincipalName]."

                $updateAccount = [PSCustomObject]@{
                    'KnUser' = @{
                        'Element' = @{
                            # Gebruiker
                            '@UsId'  = $currentAccount.Gebruiker
                            'Fields' = @{
                                # Mutatie code
                                'MtCd' = 1
                                # Omschrijving
                                "Nm"   = $currentAccount.DisplayName
                            }
                        }
                    }
                }

                if ('EmAd' -in $propertiesChanged) {
                    # E-mail werk
                    $updateAccount.'KnUser'.'Element'.'Fields'.'EmAd' = $newMailAddress
                }

                if ('Upn' -in $propertiesChanged) {
                    # UPN
                    $updateAccount.'KnUser'.'Element'.'Fields'.'Upn' = $newUserPrincipalName
                }

                $body = ($updateAccount | ConvertTo-Json -Depth 10)
                $splatWebRequest = @{
                    Uri             = $BaseUri + "/connectors/KnUser"
                    Headers         = $Headers
                    Method          = 'PUT'
                    Body            = ([System.Text.Encoding]::UTF8.GetBytes($body))
                    ContentType     = "application/json;charset=utf-8"
                    UseBasicParsing = $true
                }

                Invoke-RestMethod @splatWebRequest -Verbose:$false

                $Log = @{
                    Action            = "UpdateAccount"
                    System            = "AFAS User"
                    Message           = "Successfully updated AFAS user [$($user.employeeID)] attributes [EmAd] from [$($currentAccount.Email_werk_gebruiker)] to [$newMailAddress] and/or [userPrincipalName] from [$($currentAccount.Upn)] to [$newUserPrincipalName]"
                    IsError           = $false
                    TargetDisplayName = $user.userPrincipalName
                    TargetIdentifier  = $user.ObjectGuid
                }
                Write-Information -Tags "Audit" -MessageData $log
                break
            }
            'NoChanges' {
                $Log = @{
                    Action            = "UpdateAccount"
                    System            = "AFAS User"
                    Message           = "Successfully checked attributes [EmAd] and [Upn] of AFAS user [$($user.employeeID)]: [EmAd] [$($currentAccount.Email_werk_gebruiker)] equals [$newMailAddress] and [Upn] [$($currentAccount.Upn)] equals [$newUserPrincipalName]; no changes needed"
                    IsError           = $false
                    TargetDisplayName = $user.userPrincipalName
                    TargetIdentifier  = $user.ObjectGuid
                }
                Write-Information -Tags "Audit" -MessageData $log
                break
            }
        }
    }
    catch {
        $ex = $PSItem
        if (($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or ($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
            $errorObject = Resolve-HTTPError -ErrorObject $ex
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

        $auditMessage = "Error $($actionMessage). Error: $($ex.Exception.Message)"
        $warningMessage = "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"

        $Log = @{
            Action            = "UpdateAccount"
            System            = "AFAS User"
            Message           = "Error $($actionMessage). Error Message: $auditErrorMessage"
            IsError           = $true
            TargetDisplayName = $user.userPrincipalName
            TargetIdentifier  = $user.ObjectGuid
        }
        Write-Information -Tags "Audit" -MessageData $log
        Write-Warning $warningMessage
        Write-Error $auditMessage
    }
}
else {
    $Log = @{
        Action            = "UpdateAccount"
        System            = "AFAS User"
        Message           = "Skipped update attributes [EmAd]/[Upn] of AFAS user [$($user.employeeID)]: employeeID is empty"
        IsError           = $false
        TargetDisplayName = $user.userPrincipalName
        TargetIdentifier  = $user.ObjectGuid
    }
    Write-Information -Tags "Audit" -MessageData $log
}

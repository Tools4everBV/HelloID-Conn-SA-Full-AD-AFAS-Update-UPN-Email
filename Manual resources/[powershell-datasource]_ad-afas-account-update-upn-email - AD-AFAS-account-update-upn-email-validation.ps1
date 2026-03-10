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
        $outputMessage += " | " + $($text.Message)
    }

    $returnObject = @{
        text              = $outputMessage
        userPrincipalName = $newUserPrincipalName
        emailAddress      = $newMailAddress
    }
    Write-Output $returnObject  
}
catch {
    $ex = $PSItem
    Write-Warning "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    Write-Error "Error $($actionMessage). Error: $($ex.Exception.Message)"
}
#endregion lookup

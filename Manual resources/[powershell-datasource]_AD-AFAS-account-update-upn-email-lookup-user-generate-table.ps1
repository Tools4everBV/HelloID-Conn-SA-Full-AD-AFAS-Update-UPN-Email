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

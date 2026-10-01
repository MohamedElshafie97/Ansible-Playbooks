<#
.SYNOPSIS
    Creates AD users from a CSV file.

.DESCRIPTION
    Expected CSV columns:
        FirstName, LastName, SamAccountName, Department, Title, OU, Groups

    Groups is a semicolon-separated list. Every user gets a random initial
    password and must change it at first logon. Passwords are written to a
    separate CSV so they can be handed over securely and then deleted.
    Existing accounts are skipped, not modified. Supports -WhatIf.

.EXAMPLE
    .\New-ADUsersFromCsv.ps1 -Path .\new-hires.csv -UpnSuffix lab.local -WhatIf

.EXAMPLE
    .\New-ADUsersFromCsv.ps1 -Path .\new-hires.csv -UpnSuffix lab.local -PasswordFile C:\secure\pw.csv
#>
#Requires -Modules ActiveDirectory
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ })]
    [string]$Path,

    [Parameter(Mandatory)]
    [string]$UpnSuffix,

    [string]$PasswordFile = ".\initial-passwords-$(Get-Date -Format yyyyMMdd-HHmm).csv"
)

function New-RandomPassword {
    param([int]$Length = 16)
    $sets = @(
        'ABCDEFGHJKLMNPQRSTUVWXYZ',
        'abcdefghijkmnpqrstuvwxyz',
        '23456789',
        '!@#$%*-_=+?'
    )
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $pick = {
        param($chars)
        $b = [byte[]]::new(4); $rng.GetBytes($b)
        $chars[[BitConverter]::ToUInt32($b, 0) % $chars.Length]
    }
    $chars = foreach ($s in $sets) { & $pick $s }                      # one from each set
    $all = -join $sets
    $chars += 1..($Length - $sets.Count) | ForEach-Object { & $pick $all }
    -join ($chars | Sort-Object { Get-Random })
}

$required = 'FirstName', 'LastName', 'SamAccountName', 'OU'
$rows = Import-Csv $Path
$missing = $required | Where-Object { $_ -notin $rows[0].PSObject.Properties.Name }
if ($missing) { throw "CSV is missing column(s): $($missing -join ', ')" }

$created = foreach ($row in $rows) {
    $sam = $row.SamAccountName.Trim()

    if (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue) {
        Write-Warning "$sam already exists - skipped"
        continue
    }

    $password = New-RandomPassword
    $securePassword = [System.Security.SecureString]::new()
    foreach ($c in $password.ToCharArray()) { $securePassword.AppendChar($c) }
    $securePassword.MakeReadOnly()

    $params = @{
        Name                  = "$($row.FirstName) $($row.LastName)"
        GivenName             = $row.FirstName
        Surname               = $row.LastName
        DisplayName           = "$($row.FirstName) $($row.LastName)"
        SamAccountName        = $sam
        UserPrincipalName     = "$sam@$UpnSuffix"
        Department            = $row.Department
        Title                 = $row.Title
        Path                  = $row.OU
        AccountPassword       = $securePassword
        ChangePasswordAtLogon = $true
        Enabled               = $true
    }

    if ($PSCmdlet.ShouldProcess($sam, "Create user in $($row.OU)")) {
        try {
            New-ADUser @params -ErrorAction Stop
            foreach ($g in ($row.Groups -split ';' | Where-Object { $_.Trim() })) {
                Add-ADGroupMember -Identity $g.Trim() -Members $sam
            }
            [pscustomobject]@{ SamAccountName = $sam; InitialPassword = $password }
            Write-Verbose "Created $sam"
        }
        catch {
            Write-Error "Failed to create ${sam}: $($_.Exception.Message)"
        }
    }
}

if ($created) {
    $created | Export-Csv $PasswordFile -NoTypeInformation
    Write-Information "$(@($created).Count) user(s) created. Initial passwords in $PasswordFile - hand them over and delete the file." -InformationAction Continue
}

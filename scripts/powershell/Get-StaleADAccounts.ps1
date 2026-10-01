<#
.SYNOPSIS
    Finds Active Directory users and computers that haven't logged on in N days.

.DESCRIPTION
    Uses lastLogonTimestamp (replicated, accurate to roughly 14 days), which is
    good enough for clean-up work without querying every DC.

    Report only by default. With -Disable, accounts are disabled and moved to
    the OU given in -QuarantineOU, and a note with the date is written to the
    description. Supports -WhatIf.

.PARAMETER Days
    Inactivity threshold. Default 90.

.PARAMETER SearchBase
    OU to search. Defaults to the whole domain.

.PARAMETER Disable
    Disable the stale accounts instead of only reporting them.

.PARAMETER QuarantineOU
    Distinguished name of the OU to move disabled accounts to.

.EXAMPLE
    .\Get-StaleADAccounts.ps1 -Days 120 | Export-Csv stale.csv -NoTypeInformation

.EXAMPLE
    .\Get-StaleADAccounts.ps1 -Days 180 -Disable -QuarantineOU 'OU=Disabled,DC=lab,DC=local' -WhatIf
#>
#Requires -Modules ActiveDirectory
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [ValidateRange(30, 3650)]
    [int]$Days = 90,

    [string]$SearchBase = (Get-ADDomain).DistinguishedName,

    [switch]$Disable,

    [string]$QuarantineOU
)

if ($Disable -and -not $QuarantineOU) {
    throw 'Use -QuarantineOU together with -Disable so disabled accounts are easy to find later.'
}

$cutoff = (Get-Date).AddDays(-$Days)
# lastLogonTimestamp is stored as FILETIME; never-used accounts have no value at all
$filter = "Enabled -eq 'True' -and (lastLogonTimestamp -lt $($cutoff.ToFileTime()) -or lastLogonTimestamp -notlike '*')"
$props  = 'lastLogonTimestamp', 'whenCreated', 'Description', 'OperatingSystem'

$stale = @(
    Get-ADUser -Filter $filter -SearchBase $SearchBase -Properties $props |
        Where-Object { $_.whenCreated -lt $cutoff } |
        Select-Object @{n = 'Type'; e = { 'User' } }, Name, SamAccountName, DistinguishedName, whenCreated, Description,
                      @{n = 'LastLogon'; e = { if ($_.lastLogonTimestamp) { [datetime]::FromFileTime($_.lastLogonTimestamp) } } }

    Get-ADComputer -Filter $filter -SearchBase $SearchBase -Properties $props |
        Where-Object { $_.whenCreated -lt $cutoff } |
        Select-Object @{n = 'Type'; e = { 'Computer' } }, Name, SamAccountName, DistinguishedName, whenCreated, Description,
                      @{n = 'LastLogon'; e = { if ($_.lastLogonTimestamp) { [datetime]::FromFileTime($_.lastLogonTimestamp) } } }
)

Write-Verbose "$($stale.Count) account(s) inactive since $($cutoff.ToString('yyyy-MM-dd'))"

if (-not $Disable) {
    $stale | Sort-Object Type, LastLogon
    return
}

foreach ($acct in $stale) {
    if ($PSCmdlet.ShouldProcess($acct.SamAccountName, "Disable and move to $QuarantineOU")) {
        $note = "Disabled $(Get-Date -Format yyyy-MM-dd) - inactive $Days+ days. $($acct.Description)".Trim()
        Set-ADObject -Identity $acct.DistinguishedName -Replace @{ description = $note }
        Disable-ADAccount -Identity $acct.DistinguishedName
        Move-ADObject -Identity $acct.DistinguishedName -TargetPath $QuarantineOU
        $acct | Add-Member -NotePropertyName Action -NotePropertyValue 'Disabled' -PassThru
    }
}

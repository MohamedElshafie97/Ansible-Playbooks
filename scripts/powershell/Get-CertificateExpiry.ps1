<#
.SYNOPSIS
    Lists certificates in the local machine stores that expire soon.

.DESCRIPTION
    Checks LocalMachine\My and LocalMachine\WebHosting by default and shows
    which IIS bindings use each certificate, which is usually the first
    question when a renewal comes up.

.EXAMPLE
    .\Get-CertificateExpiry.ps1 -Days 45

.EXAMPLE
    Invoke-Command -ComputerName WEB01, WEB02 -FilePath .\Get-CertificateExpiry.ps1
#>
[CmdletBinding()]
param(
    [int]$Days = 30,
    [string[]]$Store = @('Cert:\LocalMachine\My', 'Cert:\LocalMachine\WebHosting')
)

$bindings = @{}
if (Get-Module -ListAvailable -Name WebAdministration) {
    Import-Module WebAdministration
    Get-ChildItem IIS:\SslBindings -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Thumbprint) {
            $bindings[$_.Thumbprint] += @("$($_.IPAddress):$($_.Port) $($_.Host)".Trim())
        }
    }
}

$now = Get-Date
$expiring = foreach ($s in $Store) {
    if (-not (Test-Path $s)) { continue }
    Get-ChildItem $s | Where-Object { $_.NotAfter -lt $now.AddDays($Days) } | ForEach-Object {
        [pscustomobject]@{
            Computer   = $env:COMPUTERNAME
            Store      = Split-Path $s -Leaf
            Subject    = $_.Subject
            DnsNames   = ($_.DnsNameList.Unicode -join ', ')
            Expires    = $_.NotAfter
            DaysLeft   = [int]($_.NotAfter - $now).TotalDays
            Expired    = $_.NotAfter -lt $now
            Thumbprint = $_.Thumbprint
            UsedBy     = ($bindings[$_.Thumbprint] -join '; ')
        }
    }
}

$expiring | Sort-Object DaysLeft

<#
.SYNOPSIS
    Runs the Windows System Assessment Tool (WinSAT) and gathers system reliability and stability metrics.

.DESCRIPTION
    This script performs a full WinSAT formal assessment, retrieves the latest performance scores
    (CPU, Memory, Graphics, D3D, Disk, Base), and collects reliability data including system uptime,
    unexpected shutdowns, and critical event‐log errors over the past 30 days. Outputs a PSCustomObject
    summarizing all collected data for easy reporting or further processing.

.PARAMETER None
    This script does not accept parameters. Simply run it in an elevated PowerShell session.

.EXAMPLE
    PS> .\Get-SystemHealthReport.ps1
    Runs the full assessment and outputs a report object with performance and stability metrics.

.NOTES
    File Name  : Get-SystemHealthReport.ps1
    Author     : Zach Frazier
    Created    : 2025-05-05
    Revision   : 1.0
    Requires   : Windows PowerShell 5.1 or later, WinSAT feature available
#>


# Run the full WinSAT assessment
Write-Host "Running WinSAT Formal assessment..." -ForegroundColor Cyan
Start-Process winsat -ArgumentList formal -WindowStyle Hidden -Wait

# Grab the latest WinSAT scores
$ws = Get-CimInstance -ClassName Win32_WinSat

# Reliability (Stability) Index
$rel = Get-CimInstance -ClassName Win32_ReliabilityStabilityMetrics | Sort-Object TimeGenerated -Descending | Select-Object -First 1

# Uptime & unexpected shutdowns
$os = Get-CimInstance Win32_OperatingSystem
$lastBoot = $os.LastBootUpTime
$uptimeDays = ((Get-Date) - $lastBoot).TotalDays
$shutdowns30d = (Get-WinEvent -FilterHashtable @{
        LogName   = 'System'
        Id        = 41
        StartTime = (Get-Date).AddDays(-30)
    } -ErrorAction SilentlyContinue).Count

# Event‑Log criticals last 30d
$since = (Get-Date).AddDays(-30)
$critSys = (Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = 1; StartTime = $since } -ErrorAction SilentlyContinue).Count
$critApp = (Get-WinEvent -FilterHashtable @{ LogName = 'Application'; Level = 1; StartTime = $since } -ErrorAction SilentlyContinue).Count

# Build report object with individual WinSAT scores
$report = [PSCustomObject]@{
    # cast these to doubles (decimal type)
    CPUScore               = [double]$ws.CPUScore
    MemoryScore            = [double]$ws.MemoryScore
    GraphicsScore          = [double]$ws.GraphicsScore
    D3DScore               = [double]$ws.D3DScore
    DiskScore              = [double]$ws.DiskScore
    BaseScore              = [double]$ws.WinSPRLevel
    StabilityIndex         = [double]$rel.SystemStabilityIndex

    # cast these four to integers
    UptimeDays             = [int]((Get-Date) - $lastBoot).TotalDays
    UnexpectedShutdowns30d = [int]$shutdowns30d
    CriticalSysEvents30d   = [int]$critSys
    CriticalAppEvents30d   = [int]$critApp
}


# Output Params for N-central AMP
$outCPUScore = $report.CPUScore
$outMemoryScore = $report.MemoryScore
$outGraphicsScore = $report.GraphicsScore
$outThreeDScore = $report.D3DScore
$outDiskScore = $report.DiskScore
$outBaseScore = $report.BaseScore
$outStabilityIndex = $report.StabilityIndex
$outUptimeDays = $report.UptimeDays
$outUnexpectedShutdowns = $report.UnexpectedShutdowns30d
$outCriticalSysEvents = $vCriticalSysEvents30d
$outCriticalAppEvents = $report.CriticalAppEvents30d

# Output the detailed report
$report
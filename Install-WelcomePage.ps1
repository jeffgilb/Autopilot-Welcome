function Install-WelcomePage {
    [OutputType([bool])]

    param(
        [Parameter(Mandatory)]
        [string]$Destination,
        [Parameter(Mandatory)]
        [string]$TaskName
    )

    $ErrorActionPreference = 'Stop'

    $TemplatePath = Join-Path $PSScriptRoot 'welcome.html'

    # Create welcome folder
        if (-not (Test-Path $Destination)){ 
            New-Item -Path $Destination -ItemType Directory -Force | Out-Null 
        }
        & icacls.exe $Destination /grant '*S-1-5-32-545:(OI)(CI)F' /T | Out-Null # Give standard users full control of the welcome folder
    # Copy welcome html to folder
        Copy-Item -LiteralPath $TemplatePath -Destination $Destination -Force
        $welcomeHTML = Join-Path $Destination "welcome.html"
        if (Test-Path -LiteralPath $welcomeHTML) {
            Write-Output "Welcome page template successfully staged."
        }
        else {
            throw "Failed to stage welcome page at '$welcomeHTML'."
        }

# Create launcher script
$LauncherScript = Join-Path $Destination "LaunchWelcome.ps1"
$LauncherHtmlPath = $welcomeHTML.Replace("'", "''")
@'
$ErrorActionPreference = 'Stop'

# Skip OOBE account
if ($env:USERNAME -eq "defaultuser0")
{
    exit 0
}

# Verify HTML exists
$HtmlFile = '%WELCOMEHTML%'

if (-not (Test-Path $HtmlFile))
{
    exit 0
}

# Populate the template after the interactive user has logged on. Enrollment
# data may not contain a UPN while the installation is running as SYSTEM.
$EnrollmentUpn = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Enrollments" -Recurse -ErrorAction SilentlyContinue |
    ForEach-Object {
        $Enrollment = Get-ItemProperty -Path $_.PSPath -Name UPN -ErrorAction SilentlyContinue
        if (-not [string]::IsNullOrWhiteSpace($Enrollment.UPN)) {
            $Enrollment.UPN
        }
    } |
    Select-Object -First 1

if ([string]::IsNullOrWhiteSpace($EnrollmentUpn)) {
    $DsregStatus = dsregcmd.exe /status 2>$null
    $EnrollmentUpn = ($DsregStatus |
        Select-String -Pattern '^\s*User\s*Principal\s*Name\s*:\s*(\S+)' |
        Select-Object -First 1).Matches.Groups[1].Value
}

if ([string]::IsNullOrWhiteSpace($EnrollmentUpn)) {
    $EnrollmentUpn = $env:USERNAME
}

$UserName = ($EnrollmentUpn -split '@', 2)[0]
$FirstName = ($UserName -split '[\.\-_]')[0]
if ($FirstName.Length -gt 0) {
    $FirstName = $FirstName.Substring(0,1).ToUpper() + $FirstName.Substring(1).ToLower()
}

$SerialNumber = (Get-CimInstance Win32_BIOS).SerialNumber
$ComputerName = $env:COMPUTERNAME
$OS = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$WindowsVersion = "$($OS.ProductName) ($($OS.DisplayVersion))"
$ProvisionDate = Get-Date -Format 'F'
$ReportPath = "C:\Logs\ProvisioningReport.html"
$ReportUri  = ([System.Uri]$ReportPath).AbsoluteUri

$Html = Get-Content -LiteralPath $HtmlFile -Raw
$Html = $Html.Replace('%USER%',           $FirstName)
$Html = $Html.Replace('%COMPUTERNAME%',   $ComputerName)
$Html = $Html.Replace('%SERIALNUMBER%',   $SerialNumber)
$Html = $Html.Replace('%USERNAME%',       $EnrollmentUpn)
$Html = $Html.Replace('%WINDOWSVERSION%', $WindowsVersion)
$Html = $Html.Replace('%DATE%',           $ProvisionDate)
$Html | Set-Content -LiteralPath $HtmlFile -Encoding UTF8

# Launch Edge in app mode
$HtmlUri = [System.Uri]::new($HtmlFile).AbsoluteUri
Start-Process `
    -FilePath "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" `
    -ArgumentList "--app=`"$HtmlUri`" --no-first-run"

Start-Sleep -Seconds 5

# Delete task
schtasks.exe /Delete /TN '%TASKNAME%' /F

# Remove launcher script
Remove-Item $PSCommandPath -Force -ErrorAction SilentlyContinue

exit 0
'@ | ForEach-Object {
    $_.Replace('%WELCOMEHTML%', $LauncherHtmlPath).Replace('%TASKNAME%', $TaskName.Replace("'", "''"))
} | Set-Content -Path $LauncherScript -Encoding UTF8

    if (Test-Path -LiteralPath $LauncherScript) {
        Write-Output "Welcome page launcher successfully created."
    }
    else {
        throw "Failed to create welcome page launcher at '$LauncherScript'."
    }

    # Task action
    $Action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$LauncherScript`""

    # Any-user logon trigger
    $Trigger = New-ScheduledTaskTrigger -AtLogOn

    # Delay 10 seconds after logon
    $Trigger.Delay = "PT10S"

    # Task settings
    $Settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable

    # Run in user context
    $Principal = New-ScheduledTaskPrincipal `
        -GroupId "Users" `
        -RunLevel Limited

    # Register task
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $Action `
        -Trigger $Trigger `
        -Principal $Principal `
        -Settings $Settings `
        -Force | Out-Null

    # Allow standard users to delete the task 
    $Scheduler = New-Object -ComObject 'Schedule.Service'
        $Scheduler.Connect()
        $RegisteredTask = $Scheduler.GetFolder('\').GetTask($TaskName)
        $TaskSddl = $RegisteredTask.GetSecurityDescriptor(0x7)
        $TaskSddl = $TaskSddl -replace 'D:', 'D:(A;;SD;;;BU)'
        $RegisteredTask.SetSecurityDescriptor($TaskSddl, 0)

    # Verify task exists
        $Task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($null -ne $Task) {
            Write-Output "Successfully created scheduled task '$TaskName'."
        }
        else {
            throw "Scheduled task '$TaskName' could not be verified."
        }

    return $true
}

# --------------------------------------- Create Welcome HTML Page ----------------------------------------

# Make sure the catch block works
  $ErrorActionPreference = 'Stop' 

# Super basic troubleshooting log
  $TempPath = Join-Path $env:WINDIR "Temp"
  Start-Transcript $TempPath\Autopilot-Welcome.log

try {
    $welcome = Install-WelcomePage `
		-Destination "$($env:ProgramData)\Autopilot\Welcome" `
		-TaskName "Autopilot-Welcome"

		if ($welcome -eq $true) {
			Write-Output "Autopilot welcome page and scheduled task installation completed successfully."
            Exit 0
		} else {
			Write-Output "Autopilot welcome page installation failed."
            Exit 1
		}
}
catch {
  # Do this if a terminating exception happens
    Write-Error "Autopilot welcome page installation script failure: $($_.Exception.Message)"
    Exit 2
}
finally {
    Stop-Transcript
}


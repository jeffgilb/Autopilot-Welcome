function Uninstall-WelcomePage {
    [OutputType([bool])]

    param(
        [string]$Destination = "$env:ProgramData\Autopilot\Welcome",
        [string]$TaskName = 'Autopilot-Welcome'
    )

    $ErrorActionPreference = 'Stop'

    # Remove the scheduled task if it exists.
    $Task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($null -ne $Task) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false | Out-Null
        Write-Output "Removed scheduled task '$TaskName'."
    }

    # Remove staged welcome files.
    if (Test-Path -LiteralPath $Destination) {
        $FilesToRemove = @(
            (Join-Path $Destination 'welcome.html'),
            (Join-Path $Destination 'LaunchWelcome.ps1')
        )

        foreach ($File in $FilesToRemove) {
            if (Test-Path -LiteralPath $File) {
                Remove-Item -LiteralPath $File -Force
            }
        }

        Remove-Item -LiteralPath $Destination -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Remove empty parent folder if it is now empty.
    $ParentFolder = Split-Path -Path $Destination -Parent
    if ($ParentFolder -and (Test-Path -LiteralPath $ParentFolder)) {
        $RemainingItems = Get-ChildItem -LiteralPath $ParentFolder -Force -ErrorAction SilentlyContinue
        if ($null -eq $RemainingItems -or $RemainingItems.Count -eq 0) {
            Remove-Item -LiteralPath $ParentFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    if (Test-Path -LiteralPath $Destination) {
        throw "Failed to remove welcome page installation at '$Destination'."
    }

    if ($null -ne $Task) {
        $TaskExists = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($null -ne $TaskExists) {
            throw "Scheduled task '$TaskName' could not be removed."
        }
    }

    return $true
}

# --------------------------------------- Remove Welcome Page ----------------------------------------

$ErrorActionPreference = 'Stop'
$TempPath = Join-Path $env:WINDIR 'Temp'
Start-Transcript $TempPath\Autopilot-Welcome-Uninstall.log

try {
    $uninstalled = Uninstall-WelcomePage

    if ($uninstalled -eq $true) {
        Write-Output 'Autopilot welcome page uninstall completed successfully.'
        Exit 0
    }

    Write-Output 'Autopilot welcome page uninstall failed.'
    Exit 1
}
catch {
    Write-Error "Autopilot welcome page uninstall script failure: $($_.Exception.Message)"
    Exit 2
}
finally {
    Stop-Transcript
}

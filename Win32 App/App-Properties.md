| Property | Value |
|-----|-----|
|App package file |	Install-WelcomePage.intunewin |
|Name | Autopilot Welcome Page|
|Description|A lightweight, fully automated welcome experience that launches immediately after a user's first sign-in, provides useful information about their new device via a customizable welcome.html page, and then quietly cleans itself up.|
|Publisher|	Jeff's Lab|
|App Version|1.0.0|
|Install command|Install script: <br> Install-WelcomePage.ps1
|Uninstall command|Uninstall script:<br>	Uninstall-WelcomePage.ps1
|Detection rules|File exists:<br> %ProgramData%\Autopilot\Welcome <br>	welcome.html|
|
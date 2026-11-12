# Autopilot-Welcome
This is where I stash all the goodies for a custom autopilot welcome page experience. 

This solution is a lightweight, fully automated post-Autopilot welcome experience that launches immediately after a user's first sign-in, provides useful information about their new device via a customizable welcome.html page, and then quietly cleans itself up.

The example scripts are very bare bones with minimal logging, but I figured you'd like it that way. Modify the install script and the welcome.html to do your bidding. 

When deploying as an Intune Win32 app, ensure that you include the scripts and welcome.html in the source. An example Intune Win32 app included in the Win32 App folder.

More information can be found on my blog: https://www.jeffgilb.com/giving-autopilot-a-proper-landing/

[Find me on LinkedIn](https://www.linkedin.com/in/jeffgilbert/) for feedback or suggestions on improvements.
# froxlor-installer
Bash install script to install latest version of froxlor including all required system components.  
This script should be used on new, clean, minimal installation only. As of now, only recent Debian/Ubuntu distributions are supported. Unattented install mode will be added soon.

## Installation
Login to your machine, open terminal (**ssh/shell**) and run the following command **as root**:   
`# wget -O froxlor-installer.bash https://raw.githubusercontent.com/Hosting-MP/froxlor-installer/master/froxlor-installer.bash && chmod +x froxlor-installer.bash && ./froxlor-installer.bash`

When the installation has finished open your webbrowser and finish the installation there. Return to your terminal/ssh session when you finished online installation and continue.  
After the second part of the script finished reboot your machine to make sure all changes are applied properly (especially quotas).

## Update
Not yet supported unfortunately. :/

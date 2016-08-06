# Sticky-Keys-Slayer
Scans for accessibility tools backdoors via RDP

**Twitter: [@DennisMald](https://twitter.com/DennisMald)
**Twitter: [@notmedic](https://twitter.com/notmedic)

stickyKeysSlayer.sh
----------------
Establishes a Remote Destop session (RDP) with the specified hosts and sends key presses to launch the accessibility tools within the Windows Login screen. stickyKeysSlayer.sh will analyze the console and alert if a command prompt window opens up. Screenshots will be put into a folder ('./rdp-screenshots' by default) and screenshots with a cmd.exe window are put in a subfolder ('./rdp-screenshots/discovered' by default). stickyKeysSlayer.sh accepts a single host or a list of hosts, delimited by line and works with multiple hosts in parallel.

stickyKeysSlayer.sh incorporates code from Zach Grace's [sticky_keys_hunter](https://github.com/ztgrace/sticky_keys_hunter/)

Dependencies:
----------------
* imagemagick
* xdotool
* parallel
* bc

All packages exist in the Kali repositories:

    apt-get update
    
    apt-get -y install imagemagick xdotool parallel bc
	
	
To Do:
----------------
* Detection of missed boxes (boxes to which we do not obtain a screenshot)
* Sort and unique the list, or tell people to do so
* Handle scenario when more than one window is found to share the same title. Perhaps quit if wc -l > 1 for xdotool search.
* Detect if black pixels are greater than 480,000. Means title bar went away. Possibly error out and move on

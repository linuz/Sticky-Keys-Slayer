# Sticky-Keys-Slayer
Scans for accessibility tools backdoors via RDP

**Twitter: [@DennisMald](https://twitter.com/DennisMald)**

**Twitter: [@notmedic](https://twitter.com/notmedic)**

stickyKeysSlayer.sh
----------------
Establishes a Remote Destop session (RDP) with the specified hosts and sends key presses to launch the accessibility tools within the Windows Login screen. stickyKeysSlayer.sh will analyze the console and alert if a command prompt window opens up. Screenshots will be put into a folder ('./rdp-screenshots' by default) and screenshots with a cmd.exe window are put in a subfolder ('./rdp-screenshots/discovered' by default). stickyKeysSlayer.sh accepts a single host or a list of hosts, delimited by line and works with multiple hosts in parallel.

stickyKeysSlayer.sh incorporates code from Zach Grace's [sticky_keys_hunter](https://github.com/ztgrace/sticky_keys_hunter/)

DEFCON24 Presentation Slides: [http://www.slideshare.net/DennisMaldonado5/sticky-keys-to-the-kingdom](http://www.slideshare.net/DennisMaldonado5/sticky-keys-to-the-kingdom)

Video demo of stickyKeysSlayer can be found here: [https://www.youtube.com/watch?v=Jy4hg4a1FYI](https://www.youtube.com/watch?v=Jy4hg4a1FYI)


Dependencies:
----------------
* imagemagick
* xdotool
* parallel
* bc

All packages exist in the Kali repositories:

    apt-get update
    
    apt-get -y install imagemagick xdotool parallel bc

Docker:
-------

In some situations, running this tool within Docker may be advantageous.  To do so, first build it:

```
docker build -t sticky-keys-slayer .
```

Then run the container, passing in necessary arguments to `stickyKeysSlayer.sh`:

```
docker run --rm -it --name sticky-keys-slayer --net=host sticky-keys-slayer -o /tmp/pics <target>
```

If you'd like to save the screenshots of vulnerable systems:

```
mkdir pics
docker run --rm -it --name sticky-keys-slayer --net=host -v `pwd`/pics:/tmp/foo/ sticky-keys-slayer -o /tmp/pics <target>
```

If you'd like to pass in a list of hosts to run and save the screenshots

```
mkdir pics
# put some hosts in hosts.txt
echo 192.168.0.1 > hosts.txt
docker run --rm -it --name sticky-keys-slayer --net=host -v `pwd`/hosts.txt:/tmp/hosts.txt -v `pwd`/pics:/tmp/foo/ sticky-keys-slayer -o /tmp/pics /tmp/hosts.txt
```


	
To Do:
----------------
* Detection of missed boxes (boxes to which we do not obtain a screenshot)
* Handle scenario when more than one window is found to share the same title. Perhaps quit if wc -l > 1 for xdotool search.
* Detect if black pixels are greater than 480,000. Means title bar went away. Possibly error out and move on
* Fix bug when scanning hosts with a specified port. (Ex: 192.168.0.2:34123)
* Fix whitespacing (Windows vs Linux)

FROM ubuntu:16.04
RUN apt-get update
RUN apt-get -y upgrade
RUN apt-get -y install parallel bc rdesktop imagemagick xdotool xvfb
ADD stickyKeysSlayer.sh /
ADD docker_wrapper.sh /
ENTRYPOINT ["./docker_wrapper.sh"]

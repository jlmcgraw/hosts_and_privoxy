
Automatically update hosts file and privoxy configuration on a linux machine to 
help filter undesirable content ( eg malware or ads )

Uses the following great resources
    hosts file
        "http://someonewhocares.org/hosts/ipv6/hosts"
    Adblock-to-privoxy converter data
        "https://projects.zubr.me/wiki/adblock2privoxy"

# install 7z and privoxy
    ./setup.sh

# configure privoxy
    If you want to have privoxy available to other machines on the network, you
    need to change the "listen-address" setting in "/etc/privoxy/config" to the IP address of this machine

# update crontab as needed
    # This example would run the update script every night at midnight

    sudo crontab -e

    # Add this line
    # full_path_to_file can be obtained via "readlink -f ./update_from_adblock2privoxy_and_dan_pollock_hosts.sh"
    0 0 * * * <full_path_to_file>

# set proxy via CLI
    # Perhaps there are better ways to do this, need to do some more research
    To setup the proxy environment variable as a global variable, open /etc/profile file:
        # vi /etc/profile

    Add the following information:
        export http_proxy=http://proxy-server.mycorp.com:3128/

# using proxy.pac instead
    Check out https://github.com/essandess/easylist-pac-privoxy

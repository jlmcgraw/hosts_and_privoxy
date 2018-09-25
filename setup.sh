#!/bin/bash
set -eu                 # Abort on errors and unset variables
IFS=$(printf '\n\t')    # File name separator is newline or tab, nothing else

# Install necessary software
sudo apt install \
        privoxy \
        p7zip   \
        wget
                   

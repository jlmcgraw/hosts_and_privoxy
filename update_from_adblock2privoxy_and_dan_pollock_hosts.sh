#!/bin/bash
set -eu                 # Abort on errors and unset variables
IFS=$(printf '\n\t')    # File name separator is newline or tab, nothing else

# privoxy config dir (default: /etc/privoxy/)
CONFDIR="/etc/privoxy"

# ab2p generated files
AB2P_FILES=(
    ab2p.system
    ab2p
    )

# The base name of this script
TMPNAME=$(basename "${0}")

# directory for temporary files
TMPDIR="/tmp/${TMPNAME}"

# directory for ab2p files
ab2p_dir="ab2p"

# Set the name of the lock file
LOCK_FILE="${TMPDIR}/${TMPNAME}.lock"

# Default debug level
DBG=0

# ---------------------------------------
function debug()
{
    # Print the supplied string if user supplied global debug level is greater 
    # than the parameter to function
    if [ ${DBG} -ge "${2}" ]
    then
        echo -e "${1}"
    fi
}

function usage()
{
    echo "${TMPNAME}: Download adblocking lists and install them."
    echo " "
    echo "Options:"
    echo "      -h:    Show this help."
    echo "      -q:    Don't give any output."
    echo "      -v 1:  Enable verbosity 1. Show a little bit more output."
    echo "      -v 2:  Enable verbosity 2. Show a lot more output."
    echo "      -v 3:  Enable verbosity 3. Show all possible output and don't delete temporary files.(For debugging only!!)"
}

function main()
{
    # Make copying verbose depending on verbosity setting
    cp_options=""
    [ ${DBG} -gt 0 ] && cp_options="-v"

    # Get the "ab2p.easylist_easyprivacy" archive
    wget    \
        --timestamping    \
        "https://s3.amazonaws.com/ab2p/ab2p.easylist_easyprivacy.7z"

    # Make directory if needed
    mkdir -p "${ab2p_dir}"

    # Extract the "ab2p.easylist_easyprivacy" archive
    7zr x    \
        -aoa            \
        -o${ab2p_dir}   \
        ab2p.easylist_easyprivacy.7z

    # Get the latest hosts file
    wget    \
        --timestamping  \
        "http://someonewhocares.org/hosts/ipv6/hosts"

    # Save the original hosts file
    if [ -f "/etc/hosts.original" ]
    then
        echo "Original hosts file found."
    else
        echo "Original hosts file not found."
        sudo cp /etc/hosts /etc/hosts.original
    fi

    # Add a creation date to the top of the combined hosts file
    echo "# This host file was created on $(date)" > hosts.combined

    # Combine original hosts file and Dan's to create new hosts file
    cat /etc/hosts.original hosts >> hosts.combined

    # and install it
    sudo cp hosts.combined /etc/hosts

    echo "Updating running privoxy config"
                    
    # Check that privoxy config file exists
    if [ ! -f "$CONFDIR/config" ]
    then 
        echo "ERROR: ${CONFDIR} doesn't appear to contain a privoxy configuration file"

    else
        # 4x files, 2 of each type: action/filter
        for file in "${AB2P_FILES[@]}"
            do

            # Copy the actions file to the Privoxy directory
            debug "Copying ${file}.action to ${CONFDIR} ..." 0
            
            sudo cp \
                ${cp_options}       \
                "${ab2p_dir}/privoxy/${file}.action"    \
                "${CONFDIR}"

            # If we don't see this action file in Privoxy config
            # then add it
            if [ "$(grep "${file}.action" ${CONFDIR}/config)" == "" ] 
            then
                debug "Adding action_file for ${file} to ${TMPDIR}/config ..." 0

                sed \
                    "s/^actionsfile user\.action/actionsfile ${file}.action\nactionsfile user.action/"   \
                    "${CONFDIR}/config"                                                                               \
                    > "${TMPDIR}/config"
                
                debug "... modification done.\n" 0
                
                debug "copy ${TMPDIR}/config -> ${CONFDIR} ..." 0
                
                # Copy our temporary config back to privoxy directory
                sudo cp \
                    ${cp_options}        \
                    "${TMPDIR}/config"   \
                    "${CONFDIR}"
                
                debug "... installation done\n" 0
            else
                echo "'${file}' action file already mentioned in ${CONFDIR}/config"
            fi

            # Copy the filter file to the Privoxy directory
            debug "Copying ${file}.filter ->  ${CONFDIR} ..." 0
            sudo cp \
                ${cp_options}       \
                "${ab2p_dir}/privoxy/${file}.filter"    \
                "${CONFDIR}"

            # If we don't see this filter file in Privoxy config
            # then add it
            if [ "$(grep "${file}.filter" ${CONFDIR}/config)" == "" ] 
            then
                debug "Adding filter_file for ${file} to ${TMPDIR}/config ..." 0
                
                sed \
                    "s/^\(#*\)filterfile user\.filter/filterfile ${file}.filter\n\1filterfile user.filter/"  \
                    "${CONFDIR}/config"   \
                    > "${TMPDIR}/config"
                
                debug "... modification done.\n" 0
                
                debug "copy ${TMPDIR}/config -> ${CONFDIR} ..." 0
                
                sudo cp  \
                    ${cp_options}        \
                    "${TMPDIR}/config"    \
                    "${CONFDIR}"
                
                debug "... installation done\n" 0
            else
                echo "'${file}.filter' already mentioned in ${CONFDIR}/config"
            fi

            done

        echo "Restarting privoxy"
        sudo service privoxy restart
    fi
}

# Quit if we aren't root
#  [ ${UID} -ne 0 ] && echo -e "Root privileges needed. Exit.\n\n" && usage && exit 1

# Exit if an instance is already running
if [ -e "${LOCK_FILE}" ] 
then
    echo "An instance of ${TMPNAME} is already running. Manually delete \${LOCK_FILE}\" if needed"
    exit 1
fi

# create temporary directory and lock file
mkdir -p "${TMPDIR}"
touch "${LOCK_FILE}"


# set command to be run on exit unless debug level > 2
if [ ${DBG} -le 2 ]
then
    trap "rm -rf '${TMPDIR}';exit" INT TERM EXIT
fi

# loop for options
while getopts ":hqv:" opt
do
    case "${opt}" in 
            "h")
                    usage
                    exit 0
                    ;;
            "v")
                    DBG="${OPTARG}"
                    ;;
            "q")
                    DBG=-1
                    ;;
            ":")
                    echo "${TMPNAME}: -${OPTARG} requires an argument" >&2
                    exit 1
                    ;;
            *) 
                usage
                exit 1 ;;
    esac
done


debug "Privoxy configuration directory: ${CONFDIR}" 2
debug "Temporary directory: ${TMPDIR}" 2

# Run the main loop
main

# restore default exit command
trap - INT TERM EXIT

# Remove temporary directory
if [ ${DBG} -lt 2 ]
then
    rm -r "${TMPDIR}"
fi

# Remove temporary directory
if [ ${DBG} -eq 2 ] 
then    
    rm -vr "${TMPDIR}"
fi

exit 0

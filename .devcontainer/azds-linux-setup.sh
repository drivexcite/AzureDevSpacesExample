#!/bin/bash

info()    { echo "[INFO]    $*" ; }
fatal()   { echo "[FATAL]   $*" ; exit 1 ; }

PRODUCT_NAME="Azure Dev Spaces"

# Check system configuration
if [ -z "$(uname -m | grep 64)" ]; then
    fatal "$PRODUCT_NAME is only supported on x64 architectures."
fi

function dotNetInstallErrorMsg() 
{
    info "Failed to install dotnet core dependencies."
    info "You can manually install all required dependencies based on the following documentation:"
    fatal "https://www.microsoft.com/net/download/dotnet-core/2.1"
}

function packageMgrError()
{
    fatal "Failed to find $1 tool. Please install manually and re-run this script."
}

function installPackage()
{
    {
        info "Installing ${@:2}..."
        sudo $1 update && sudo $1 install -y ${@:2}
    }||{
        fatal "Failed to install ${@:2}."
    }
}

# Returns the type of OS by reading the "ID" field from the /etc/os-release
function getOSType()
{
    OS_TYPE=$(grep -w "ID" /etc/os-release | cut -f2 -d=)
    OS_TYPE="${OS_TYPE%\"}"
    echo "${OS_TYPE#\"}" | tr '[:upper:]' '[:lower:]'
}

function getOSVersion()
{
    VERSION=$(grep -w "VERSION_ID" /etc/os-release | cut -f2 -d=)
    # Remove trailing and leading quotes if present
    VERSION="${VERSION%\"}"
    echo "${VERSION#\"}"
}

SETUP_SRC_LOCATION="https://azuredevspacestools.blob.core.windows.net/azdssetup"
BINARIES_FILE_NAME=AzdsCliLinux.zip
TMP_FOLDER="/tmp"
LIB_FOLDER="$HOME/lib/azds-cli"
BIN_FOLDER="/usr/local/bin/azds"
KUBECTL_PATH="$LIB_FOLDER/kubectl/linux/kubectl"
INSTALL_PREREQS=false

echo "Installing $PRODUCT_NAME client components..."

DEPS=".NET Core Runtime"
if ! which unzip >/dev/null 2>/dev/null; then
    DEPS="unzip, $DEPS"
    UNZIP=1
fi
if ! which curl >/dev/null 2>/dev/null; then
    DEPS="curl, $DEPS"
    CURL=1
fi
if ! which xdg-open >/dev/null 2>/dev/null; then
    DEPS="xdg-utils, $DEPS"
    XDG_UTILS=1
fi

echo "The following dependencies will be installed: $DEPS"
sudo echo 

# Determine OS type 
# Debian based OS (Debian, Ubuntu, Linux Mint) has /etc/debian_version
# Fedora based OS (Fedora, Redhat, Centos) has /etc/redhat-release
# SUSE based OS (OpenSUSE, SUSE Enterprise) has ID_LIKE=suse in /etc/os-release

if [ -e /etc/os-release ]; then
    OS_TYPE=$(getOSType)
    OS_VERSION=$(getOSVersion)
    if [ -e /etc/debian_version ]; then
        TMP=$(command -v apt-get)
        if [ $? != 0 ]; then
            packageMgrError 'apt-get'
        fi
        # Setup unzip utility
        if [ -n "$UNZIP" ]; then
            installPackage apt-get unzip
        fi

        # Setup curl utility
        if [ -n "$CURL" ]; then
            installPackage apt-get curl
        fi

        # Setup xdg-utils utility
        if [ -n "$XDG_UTILS" ]; then
            installPackage apt-get xdg-utils
        fi

        # Handle the ubuntu soruces and installation
        if [ "$OS_TYPE" = "ubuntu" ]; then
        { # Setup the sources first and then install the .NET core runtime
            sudo curl -s -o packages-microsoft-prod.deb https://packages.microsoft.com/config/ubuntu/$OS_VERSION/packages-microsoft-prod.deb &&
            sudo dpkg -i packages-microsoft-prod.deb &&
            sudo apt-get install -y apt-transport-https &&
            sudo apt-get update &&
            sudo apt-get install -y aspnetcore-runtime-2.1
        }||{
            dotNetInstallErrorMsg
        }
        elif [ "$OS_TYPE" = "debian" ]; then
        {
            sudo curl -s https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.asc.gpg && 
            sudo mv microsoft.asc.gpg /etc/apt/trusted.gpg.d/microsoft.asc.gpg &&
            sudo curl -s -o /etc/apt/sources.list.d/microsoft-prod.list https://packages.microsoft.com/config/debian/$OS_VERSION/prod.list &&
            sudo chown root:root /etc/apt/trusted.gpg.d/microsoft.asc.gpg &&
            sudo chown root:root /etc/apt/sources.list.d/microsoft-prod.list &&
            sudo apt-get install -y apt-transport-https &&
            sudo apt-get update &&
            sudo apt-get install -y aspnetcore-runtime-2.1
        }||{
            dotNetInstallErrorMsg
        }
        else
            INSTALL_PREREQS=true
        fi
    elif [ -e /etc/redhat-release ]; then
        # use dnf on fedora
        # use yum on centos and redhat
        if [ -e /etc/fedora-release ]; then
            TMP=$(command -v dnf)
            if [ $? != 0 ]; then
               packageMgrError 'dnf'
            fi
            
            # Setup unzip utility
            if [ -n "$UNZIP" ]; then
                installPackage dnf unzip
            fi

            # Setup curl utility
            if [ -n "$CURL" ]; then
                installPackage dnf curl
            fi

            # Setup xdg-utils utility
            if [ -n "$XDG_UTILS" ]; then
                installPackage dnf xdg-utils
            fi

            # Register the sources and Install .NET core runtime
            {
                sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc &&
                sudo curl -s -o /etc/yum.repos.d/microsoft-prod.repo https://packages.microsoft.com/config/fedora/27/prod.repo &&
                sudo chown root:root /etc/yum.repos.d/microsoft-prod.repo &&
                sudo dnf update &&
                sudo dnf install -y aspnetcore-runtime-2.1
            }||{
                dotNetInstallErrorMsg
            }
        else
            TMP=$(command -v yum)
            if [ $? != 0 ]; then
               packageMgrError 'yum'
            fi

            # Setup unzip utility
            if [ -n "$UNZIP" ]; then
                installPackage yum unzip
            fi

            # Setup curl utility
            if [ -n "$CURL" ]; then
                installPackage yum curl
            fi

            # Setup xdg-utils utility
            if [ -n "$XDG_UTILS" ]; then
                installPackage yum xdg-utils
            fi

            if [ "$OS_TYPE" = "rhel" ]; then
                {
                    sudo yum update &&
                    sudo yum install rh-dotnet21 -y && 
                    {
                        grep -q -s '^source scl_source enable rh-dotnet21$' ~/.bashrc ||
                        echo "source scl_source enable rh-dotnet21" >> ~/.bashrc 
                    }
                }||{
                    dotNetInstallErrorMsg
                }
            elif [ ! $(rpm -q aspnetcore-runtime-2.1 --quiet) ]; then # yum install fails if the package is already installed, so if the aspnetcore-runtime-2.1 is not installed already
                {
                    sudo rpm -UFvh https://packages.microsoft.com/config/rhel/7/packages-microsoft-prod.rpm &&
                    sudo yum update &&
                    sudo yum install -y aspnetcore-runtime-2.1
                }||{
                    dotNetInstallErrorMsg
                }
            fi
        fi
    else
        # we might be on OpenSUSE
        if [ "$OS_TYPE" = "opensuse" ] || [ "$OS_TYPE" = "sles" ]; then
            TMP=$(command -v zypper)
            if [ $? != 0 ]; then
              packageMgrError 'zypper'
            fi

            # Setup unzip utility
            if [ -n "$UNZIP" ]; then
                installPackage zypper unzip
            fi

            # Setup curl utility
            if [ -n "$CURL" ]; then
                installPackage zypper curl
            fi

            # Setup xdg-utils utility
            if [ -n "$XDG_UTILS" ]; then
                installPackage yum xdg-utils
            fi

            info "The installation may report that nothing provides libcurl. The error will present 2 'solutions'. Choose 'Solution 2' to continue installing .NET."
            echo

            if [ "$OS_TYPE" = "sles" ]; then
                sudo rpm -UFvh https://packages.microsoft.com/config/sles/12/packages-microsoft-prod.rpm || dotNetInstallErrorMsg
            else
                {
                    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc &&
                    sudo curl -o /etc/zypp/repos.d/microsoft-prod.repo https://packages.microsoft.com/config/opensuse/42.2/prod.repo &&
                    sudo chown root:root /etc/zypp/repos.d/microsoft-prod.repo
                } || {
                    dotNetInstallErrorMsg
                }
            fi

            # Install .Net core runtime
            {
                sudo zypper update &&
                sudo zypper install aspnetcore-runtime-2.1
            }||{
                dotNetInstallErrorMsg
            }
        else
            INSTALL_PREREQS=true
        fi
    fi
else
    INSTALL_PREREQS=true
fi

for var in "$@"; do
  if ! [ "$var" = "-y" ] && ! [ "$var" = "-yes" ] && ! [ "$var" = "--yes" ]; then
    BuildOverride=$var
  fi
done

if [ "$BuildOverride" = "PreRelease" ]; then
    SETUP_SRC_LOCATION="$SETUP_SRC_LOCATION/PreRelease"
    info "Will install build '$BuildOverride' specific binaries."
elif [ -n "$BuildOverride" ]; then
    SETUP_SRC_LOCATION="$SETUP_SRC_LOCATION/CLI.$BuildOverride"
    info "Will install build '$BuildOverride' specific binaries."
else
    SETUP_SRC_LOCATION="$SETUP_SRC_LOCATION/LKS"
fi

# Setup AZDS CLI
if [ -e "$BIN_FOLDER" -o -e "$LIB_FOLDER" ]; then
    info "Removing existing versions of $PRODUCT_NAME..."
    sudo rm -rf "$BIN_FOLDER"
    sudo rm -rf "$LIB_FOLDER"
fi

if [ ! -e "$BINARIES_FILE_NAME" ]; then
    {
        info "Downloading $PRODUCT_NAME Package..."
        curl -fsS $SETUP_SRC_LOCATION/$BINARIES_FILE_NAME -o "$TMP_FOLDER/.azds.zip"
    }||{
        fatal "Failed to download $PRODUCT_NAME Package."
    }
else
    sudo cp "$BINARIES_FILE_NAME" "$TMP_FOLDER/.azds.zip"
fi

{
    sudo mkdir -p "$LIB_FOLDER" &&
    unzip -q "$TMP_FOLDER/.azds.zip" -d "$TMP_FOLDER/setup" &&
    sudo mv -f "$TMP_FOLDER/setup"/* "$LIB_FOLDER/" &&
    rm -f "$TMP_FOLDER/.azds.zip" &&
    rm -rf "$TMP_FOLDER/setup" &&
    sudo chmod +x "$LIB_FOLDER/azds" &&
    sudo chmod +x "$KUBECTL_PATH" &&
    sudo ln -sfn "$LIB_FOLDER/azds" "$BIN_FOLDER"
}||{
    fatal "Failed to install $PRODUCT_NAME."
}

BASH_COMPLETION_SCRIPT=bash_completion.sh
if [ ! -e $BASH_COMPLETION_SCRIPT ]; then
    {
        info "Downloading Bash completion script..."
        curl -fsS $SETUP_SRC_LOCATION/$BASH_COMPLETION_SCRIPT -o "$TMP_FOLDER/.azds.bash_completion.sh"
    }||{
        fatal "Failed to download Bash completion script."
    }
else
    sudo cp $BASH_COMPLETION_SCRIPT "$TMP_FOLDER/.azds.bash_completion.sh"
fi
{
    sudo mkdir -p /etc/bash_completion.d &&
    sudo mv "$TMP_FOLDER/.azds.bash_completion.sh" /etc/bash_completion.d/azds &&
    sudo chmod 777 /etc/bash_completion.d/azds
}||{
    fatal "Failed to enable Bash completion script."
}
{
    grep -q -s '^source /etc/bash_completion.d/azds$' ~/.bash_profile ||
    echo "source /etc/bash_completion.d/azds" >> ~/.bash_profile
}||{
    fatal "Failed to register Bash completion script."
}

echo 
info "Successfully installed $PRODUCT_NAME to '$BIN_FOLDER'."
info "Run 'source ~/.bash_profile' for enabling auto completion of commands."

if [ $INSTALL_PREREQS = 'true' ]
    then
    info "***Note*** the $PRODUCT_NAME won't work until the following dependencies are installed:"
    info ".NET Core dependencies: https://docs.microsoft.com/en-us/dotnet/core/linux-prerequisites?tabs=netcore2x"
fi
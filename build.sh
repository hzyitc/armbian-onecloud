#!/bin/bash
# A simple script for creating single images. Modified from ci.yml
# It's useful if you want to make some changes to the source code and not willing to build it again step by step!
# SydneyMrCat@2023/4/28

set -e

# Output color...
C_RESET="\e[0m"
C_BLACK="\e[30m"
C_RED="\e[31m"
C_GREEN="\e[32m"
C_YELLOW="\e[33m"
C_BLUE="\e[34m"
C_MAGENTA="\e[35m"
C_CYAN="\e[36m"
C_GRAY="\e[37m"

# Here we defines some variables...
SCRIPT_REPO=hzyitc/armbian-onecloud
SCRIPT_REF=readme
UBOOT_REPO=hzyitc/u-boot-onecloud
UBOOT_RELEASE=latest
UBOOT_BURNIMG=eMMC.burn.img
ARMBIAN_REPO=armbian/build
ARMBIAN_REF=main
DESKTOP_ENVIRONMENT=xfce
DESKTOP_ENVIRONMENT_CONFIG_NAME=config_base
DESKTOP_APPGROUPS_SELECTED=
PATCHES=(4077 5076 5082)
AMLIMG_VERSION="v0.3.1"

# Available choices...
BRANCH=(edge,current)
RELEASE=(jammy,bullseye,sid)
TYPE=(minimal,cli,desktop)

# Default choices...
INTERACTIVE=false
CHOOSED_BRANCH=current
CHOOSED_RELEASE=jammy
CHOOSED_TYPE=minimal
SKIP_PATCH=false
SKIP_CLONE=false
NOT_CREATE_BURNABLE=false
LOCAL_REPO_ADDR=$(pwd)/build_onecloud/build
OUTPUT_DIR=$(pwd)/build_onecloud/dist

# Show usages...
usage(){
cat << EOF
Usage: $0 [OPTION]
-h,--help: Show help infomation
-b,--branch: Branch to be built, choose from ${BRANCH[*]}. Default is $CHOOSED_BRANCH.
-n,--no-burnable-images: Don't Create burnable images. Default is $NOT_CREATE_BURNABLE.
-r,--release: Release to be built, choose from ${RELEASE[*]}. Default is $CHOOSED_RELEASE.
-t,--type: Type to be built, choose from ${TYPE[*]}. Default is $CHOOSED_TYPE.
-l,--local-repo-addr: Specify local repository location. \
If you use this option, the script will no longer clone the source code from $ARMBIAN_REPO, and will use location you specified.\
 This will be helpful if you want to make some changes to the source code, \
 for example, config/kernel/xxx.config. Default is $LOCAL_REPO_ADDR.
-s,--skip-patch: Skip apply patch to source code. Default is $SKIP_PATCH.
-o,--output-dir: specify a directory to storage artifacts. Default is $OUTPUT_DIR.
-i,--interactive: use dialog to ask user for build args.
example: ./build.sh -b current -r jammy -t minimal
EOF
}
interactive(){
echo "Installing Dialog...."
sudo sudo apt-get -qqqqq update && apt-get -qqqqq install dialog -y
dialog --title "Onecloud Build" --msgbox "Now this script will guide you to build your armbian image for onecloud." 20 50
if dialog --title "Build from local"  --defaultno --yesno "Do you want to build from local repo?" 10 30; then
SKIP_CLONE=true
dialog --title "Select or input yout repo position" --fselect / 7 60 2> /tmp/dialog_onecloud.txt
_LOCAL_REPO_ADDR=$(cat /tmp/dialog_onecloud.txt)
if [ -n $_LOCAL_REPO_ADDR ];then
LOCAL_REPO_ADDR=$_LOCAL_REPO_ADDR
fi
if dialog --title "Apply Patch" --defaultno --yesno "Do you want to Apply patches automatically?" 10 30; then
SKIP_PATCH=true
fi
fi

if dialog --title "Build Burnable Images" --yesno "Do you want to build Burnable images?" 10 30; then
NOT_CREATE_BURNABLE=false
else
NOT_CREATE_BURNABLE=true
fi

if dialog --title "Select output directory" --defaultno --yesno "Do you want to select a output directory, default is $OUTPUT_DIR?" 10 60; then
dialog --title "Select output directory" --fselect / 7 60 2> /tmp/dialog_onecloud.txt
_OUTPUT_DIR=$(cat /tmp/dialog_onecloud.txt)
if [ -n $_OUTPUT_DIR ];then
OUTPUT_DIR=$_OUTPUT_DIR
fi
fi

dialog --title "Select build branch" --clear --menu \
    "Please choose branch to be built, default is $CHOOSED_BRANCH: " 16 51 3 \
    current "Build branch current" \
    edge "Build branch edge" 2>/tmp/dialog_onecloud.txt
_CHOOSED_BRANCH=$(cat /tmp/dialog_onecloud.txt)
if [ -n $_CHOOSED_BRANCH ];then
CHOOSED_BRANCH=$_CHOOSED_BRANCH
fi

dialog --title "Select build release" --clear --menu \
    "Please choose release to be built, default is $CHOOSED_RELEASE: " 16 51 3 \
    jammy "Build release jammy" \
    bullseye "Build release bullseye" \
	sid "Build release sid" 2>/tmp/dialog_onecloud.txt
_CHOOSED_RELEASE=$(cat /tmp/dialog_onecloud.txt)
if [ -n $_CHOOSED_RELEASE ];then
CHOOSED_RELEASE=$_CHOOSED_RELEASE
fi

dialog --title "Select build type" --clear --menu \
    "Please choose type to be built, default is $CHOOSED_TYPE: " 16 51 3 \
    minimal "Build type minimal" \
    cli "Build type cli" \
	desktop "Build type desktop" 2>/tmp/dialog_onecloud.txt
_CHOOSED_TYPE=$(cat /tmp/dialog_onecloud.txt)
if [ -n $_CHOOSED_TYPE ];then
CHOOSED_TYPE=$_CHOOSED_TYPE
fi
if [[ $CHOOSED_TYPE == "desktop" ]];then
if dialog --title "ADVANCED" --defaultno --yesno "Do you want to specify other configs, including DESKTOP_ENVIRONMENT,DESKTOP_ENVIRONMENT_CONFIG_NAME,DESKTOP_APPGROUPS_SELECTED?" 10 60; then
USER_INPUT=$(dialog --title "Advanced option" \
                    --output-fd 1 \
                    --output-separator "," \
                    --form "Input configs:" 12 80 4  \
                        "DESKTOP_ENVIRONMENT:"  1  1 "$DESKTOP_ENVIRONMENT" 1  40  25  0  \
                        "Full DESKTOP_ENVIRONMENT_CONFIG_NAME:" 2  1 "$DESKTOP_ENVIRONMENT_CONFIG_NAME" 2  40  25  0  \
                        "DESKTOP_APPGROUPS_SELECTED:"  3  1 "$DESKTOP_APPGROUPS_SELECTED" 3  40  25  0)
RET_ARRAY=($USER_INPUT)
if [ -n $RET_ARRAY[0] ];then
DESKTOP_ENVIRONMENT=$RET_ARRAY[0]
fi
if [ -n $RET_ARRAY[1] ];then
DESKTOP_ENVIRONMENT_CONFIG_NAME=$RET_ARRAY[1]
fi
if [ -n $RET_ARRAY[2] ];then
DESKTOP_APPGROUPS_SELECTED=$RET_ARRAY[2]
fi
fi
fi
dialog --title "Onecloud Build" --msgbox "Configs collected. Press Enter to start building!" 20 50
# echo "ddd"
dialog --clear
rm -rf /tmp/dialog_onecloud.txt
}
# Run build
run_build(){

mkdir -p $LOCAL_REPO_ADDR
mkdir -p $OUTPUT_DIR/debs

# Install Dependents...
echo -n "Install Dependents..."
sudo apt-get -qqqqq update && sudo apt-get -qqqqq install img2simg jq git -y
echo "Done"

# Gather infomation...
echo -n "Getting repo info..."
SCRIPT_SHA=$(curl -sS https://api.github.com/repos/${SCRIPT_REPO}/commits/${SCRIPT_REF} | jq -r .sha)
UBOOT_TAG=$(curl -sS https://api.github.com/repos/${UBOOT_REPO}/releases/${UBOOT_RELEASE} | jq -r .tag_name)
ARMBIAN_SHA=$(curl -sS https://api.github.com/repos/${ARMBIAN_REPO}/commits/${ARMBIAN_REF} | jq -r .sha)
echo "Done"

echo -e \
"$(cat <<EOF | sed -E 's/^  //'
-------------------------------
Script: ${C_BLUE}${SCRIPT_REPO}${C_RESET}@${C_MAGENTA}${SCRIPT_REF}${C_RESET}(https://github.com/${SCRIPT_REPO}/tree/${SCRIPT_REF})
    ${C_YELLOW}${SCRIPT_SHA}${C_RESET}(https://github.com/${SCRIPT_REPO}/tree/${SCRIPT_SHA})
U-Boot: ${C_BLUE}${UBOOT_REPO}${C_RESET}@${C_MAGENTA}${UBOOT_RELEASE}${C_RESET}(https://github.com/${UBOOT_REPO}/releases/tag/${UBOOT_RELEASE})
    ${C_MAGENTA}${UBOOT_TAG}${C_RESET}(https://github.com/${UBOOT_REPO}/releases/tag/${UBOOT_TAG})
Armbian: ${C_BLUE}${ARMBIAN_REPO}${C_RESET}@${C_MAGENTA}${ARMBIAN_REF}${C_RESET}(https://github.com/${ARMBIAN_REPO}/tree/${ARMBIAN_REF})
    ${C_YELLOW}${ARMBIAN_SHA}${C_RESET}(https://github.com/${ARMBIAN_REPO}/tree/${ARMBIAN_SHA})
EOF
)"
if [[ -n "${PATCHES}" ]]; then
	echo -e "\nPatches:"
	for id in ${PATCHES[@]}
	do
		echo -e "  ${C_BLUE}armbian/build${C_RESET}#${C_MAGENTA}${id}${C_RESET}(http://github.com/armbian/build/pull/${id})"
	done
else
	SKIP_PATCH=true
fi
echo "-------------------------------"

if [ "$SKIP_CLONE" = false ];then
	echo "Cloning armbian/build..."
	git clone https://github.com/armbian/build.git --depth=1 $LOCAL_REPO_ADDR
fi

cd $LOCAL_REPO_ADDR
# Apply patch here...
if [ "$SKIP_PATCH" = false ];then
	echo "Applying patches..."
	for id in ${PATCHES[@]}
	do
		curl -L -sS -O "https://github.com/armbian/build/pull/$id.patch"
	done
	for file in *.patch; do
		patch --batch -p1 -N <"$file"
	done
	rm *.patch
fi
# Removed - Building image will also build these packages.
# echo "Building dtb/headers/image debs..."
# ./compile.sh kernel \
# 	ALLOW_ROOT=yes \
# 	BOARD=onecloud \
# 	BRANCH=$CHOOSED_BRANCH \
# 	EXPERT=yes \
# 	USE_CCACHE=no
# mv output/debs/* $OUTPUT_DIR/debs
# rm -rf output
# echo "Done."

echo "Building image..."
./compile.sh build \
	ALLOW_ROOT=yes \
	BOARD=onecloud \
	BRANCH=$CHOOSED_BRANCH \
	RELEASE=$CHOOSED_RELEASE \
	KERNEL_CONFIGURE=no \
	BUILD_MINIMAL=$([ "$CHOOSED_TYPE" == 'minimal' ] && echo 'yes' || echo 'no') \
	BUILD_DESKTOP=$([ "$CHOOSED_TYPE" == 'desktop' ] && echo 'yes' || echo 'no') \
	DESKTOP_ENVIRONMENT=$([ "$CHOOSED_TYPE" == 'desktop' ] && echo $DESKTOP_ENVIRONMENT || echo '') \
	DESKTOP_ENVIRONMENT_CONFIG_NAME=$([ "$CHOOSED_TYPE" == 'desktop' ] && echo $DESKTOP_ENVIRONMENT_CONFIG_NAME || echo '') \
	DESKTOP_APPGROUPS_SELECTED=$([ "$CHOOSED_TYPE" == 'desktop' ] && echo $DESKTOP_APPGROUPS_SELECTED || echo '') \
	EXPERT=yes \
	SKIP_EXTERNAL_TOOLCHAINS=yes \
	CLEAN_LEVEL= \
	USE_CCACHE=no \
	COMPRESS_OUTPUTIMAGE=img

mv output/debs/* $OUTPUT_DIR/debs

if [ "$NOT_CREATE_BURNABLE" = false ];then

echo "Downloading AmlImg..."
curl -sSL -o ./AmlImg https://github.com/hzyitc/AmlImg/releases/download/$AMLIMG_VERSION/AmlImg_${AMLIMG_VERSION}_linux_amd64
chmod +x ./AmlImg

echo "Downloading uboot..."
curl -sSL -o ./uboot.img https://github.com/${UBOOT_REPO}/releases/download/${UBOOT_TAG}/${UBOOT_BURNIMG}

echo "Unpacking uboot..."
./AmlImg unpack ./uboot.img burn/

echo "Extracting boot and rootfs partitions..."
diskimg=$(ls output/images/*.img)
loop=$(sudo losetup --find --show --partscan $diskimg)
img2simg ${loop}p1 burn/boot.simg
img2simg ${loop}p2 burn/rootfs.simg
losetup -d $loop

echo "Generating burnable image..."
echo -n "sha1sum $(sha1sum burn/boot.simg | awk '{print $1}')" >burn/boot.VERIFY
echo -n "sha1sum $(sha1sum burn/rootfs.simg | awk '{print $1}')" >burn/rootfs.VERIFY
cat <<EOF >>burn/commands.txt
PARTITION:boot:sparse:boot.simg
VERIFY:boot:normal:boot.VERIFY
PARTITION:rootfs:sparse:rootfs.simg
VERIFY:rootfs:normal:rootfs.VERIFY
EOF
prefix=$(ls output/images/*.img | sed 's/\.img$//')
burnimg=${prefix}.burn.img
./AmlImg pack $burnimg burn/
fi

echo "Hashing images..."

# There should be only one image if use -n.
for f in output/images/*.img; do
	sha256sum "$f" >"${f}.sha"
	# We don't need to upload them to releases so, no compresses.
	# xz --threads=0 --compress "$f"
done

# Image built. now transfer it to the dist directory.
mv output/images/*.sha $OUTPUT_DIR
mv output/images/*.img $OUTPUT_DIR

# Now we remove useless caches.
rm -rf output/ burn/ ./AmlImg *.img *.patch
echo "You can now find dists at $OUTPUT_DIR"
echo "All done. You are ready to go :)"
exit 0
}


# Fetch user options
OPTIONS=`getopt -o hsio:b:r:t:l: --long help,skip-patch,interactive,branch:,release:,type:,local-repo-addr:,output-dir: -n $0 -- "$@"`
if [ $? != 0 ];then
	usage
	exit 1
fi
eval set -- "${OPTIONS}"
while true
do
    case $1 in
        -b|--branch)
            CHOOSED_BRANCH=$2
			[[ ${BRANCH[@]/${CHOOSED_BRANCH}/} != ${BRANCH[@]} ]] && echo "Branch $CHOOSED_BRANCH is choosed." || (echo "You should choose from ${BRANCH[*]}." && exit 1)
            shift
            ;;
        -r|--release)
            CHOOSED_RELEASE=$2
			[[ ${RELEASE[@]/${CHOOSED_RELEASE}/} != ${RELEASE[@]} ]] && echo "Release $CHOOSED_RELEASE is choosed." || (echo "You should choose from ${RELEASE[*]}." && exit 1)
            shift
            ;;
        -t|--type)
            CHOOSED_TYPE=$2
			[[ ${TYPE[@]/${CHOOSED_TYPE}/} != ${TYPE[@]} ]] && echo "Type $CHOOSED_TYPE is choosed." || (echo "You should choose from ${TYPE[*]}." && exit 1)
            shift
            ;;
		-l|--local-repo-addr)
			SKIP_CLONE=true
            LOCAL_REPO_ADDR=$2
			if [ ! -d $LOCAL_REPO_ADDR ];then
				echo $LOCAL_REPO_ADDR:Directory not found.
				exit 1
			fi
            shift
            ;;
		-o|--output-dir)
            OUTPUT_DIR=$2
			shift
            ;;
		-h|--help)
            usage
            ;;
		-s|--skip-patch)
            SKIP_PATCH=true
            ;;
		-n|--no-burnable-images)
            NOT_CREATE_BURNABLE=true
            ;;
		-i|--interactive)
            INTERACTIVE=true
            ;;
        --)
            shift
            break
            ;;
        *)
            usage
            exit 1
            ;;
    esac
shift
done
# usage

# Check if running with root...
if [ `id -u` -ne 0 ];then
	echo "Plz Use sudo to run this script"
    exit 0
fi
if [ "$INTERACTIVE" = true ];then
interactive
fi
run_build
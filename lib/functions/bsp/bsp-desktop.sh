#!/bin/bash
#
# Copyright (c) 2013-2021 Igor Pecovnik, igor.pecovnik@gma**.com
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.
#
# This file is a part of the Armbian build script
# https://github.com/armbian/build/

create_desktop_package() {
	display_alert "bsp-desktop: PACKAGE_LIST_DESKTOP" "'${PACKAGE_LIST_DESKTOP}'" "debug"

	# Remove leading and trailing spaces with some bash monstruosity
	# https://stackoverflow.com/questions/369758/how-to-trim-whitespace-from-a-bash-variable#12973694
	DEBIAN_RECOMMENDS="${PACKAGE_LIST_DESKTOP#"${PACKAGE_LIST_DESKTOP%%[![:space:]]*}"}"
	DEBIAN_RECOMMENDS="${DEBIAN_RECOMMENDS%"${DEBIAN_RECOMMENDS##*[![:space:]]}"}"
	# Replace whitespace characters by commas
	DEBIAN_RECOMMENDS=${DEBIAN_RECOMMENDS// /,}
	# Remove others 'spacing characters' (like tabs)
	DEBIAN_RECOMMENDS=${DEBIAN_RECOMMENDS//[[:space:]]/}

	display_alert "bsp-desktop: DEBIAN_RECOMMENDS" "'${DEBIAN_RECOMMENDS}'" "debug"

	# Replace whitespace characters by commas
	PACKAGE_LIST_PREDEPENDS=${PACKAGE_LIST_PREDEPENDS// /,}
	# Remove others 'spacing characters' (like tabs)
	PACKAGE_LIST_PREDEPENDS=${PACKAGE_LIST_PREDEPENDS//[[:space:]]/}

	local destination tmp_dir
	tmp_dir=$(mktemp -d) # subject to TMPDIR/WORKDIR, so is protected by single/common error trapmanager to clean-up.
	destination=${tmp_dir}/${BOARD}/${CHOSEN_DESKTOP}_${REVISION}_all
	rm -rf "${destination}"
	mkdir -p "${destination}"/DEBIAN

	display_alert "bsp-desktop: PACKAGE_LIST_PREDEPENDS" "'${PACKAGE_LIST_PREDEPENDS}'" "debug"

	# set up control file
	cat <<- EOF > "${destination}"/DEBIAN/control
		Package: ${CHOSEN_DESKTOP}
		Version: $REVISION
		Architecture: all
		Maintainer: $MAINTAINER <$MAINTAINERMAIL>
		Installed-Size: 1
		Section: xorg
		Priority: optional
		Recommends: ${DEBIAN_RECOMMENDS//[:space:]+/,}, armbian-bsp-desktop
		Provides: ${CHOSEN_DESKTOP}, armbian-${RELEASE}-desktop
		Pre-Depends: ${PACKAGE_LIST_PREDEPENDS//[:space:]+/,}
		Description: Armbian desktop for ${DISTRIBUTION} ${RELEASE}
	EOF

	# Recreating the DEBIAN/postinst file
	echo "#!/bin/sh -e" > "${destination}/DEBIAN/postinst"

	local aggregated_content=""
	aggregate_all_desktop "debian/postinst" $'\n'

	echo "${aggregated_content}" >> "${destination}/DEBIAN/postinst"
	echo "exit 0" >> "${destination}/DEBIAN/postinst"

	chmod 755 "${destination}"/DEBIAN/postinst

	# Armbian create_desktop_package scripts

	unset aggregated_content

	mkdir -p "${destination}"/etc/armbian

	local aggregated_content=""
	aggregate_all_desktop "armbian/create_desktop_package.sh" $'\n'
	eval "${aggregated_content}"
	[[ $? -ne 0 ]] && display_alert "create_desktop_package.sh exec error" "" "wrn"

	display_alert "Building desktop package" "${CHOSEN_DESKTOP}_${REVISION}_all" "info"

	mkdir -p "${DEB_STORAGE}/${RELEASE}"
	cd "${destination}"
	cd ..
	fakeroot_dpkg_deb_build "${destination}" "${DEB_STORAGE}/${RELEASE}/${CHOSEN_DESKTOP}_${REVISION}_all.deb"

	unset aggregated_content

}

create_bsp_desktop_package() {

	display_alert "Creating board support package for desktop" "${package_name}" "info"

	local package_name="${BSP_DESKTOP_PACKAGE_FULLNAME}"

	local destination tmp_dir
	tmp_dir=$(mktemp -d) # subject to TMPDIR/WORKDIR, so is protected by single/common error trapmanager to clean-up.
	destination=${tmp_dir}/${BOARD}/${BSP_DESKTOP_PACKAGE_FULLNAME}
	rm -rf "${destination}"
	mkdir -p "${destination}"/DEBIAN

	copy_all_packages_files_for "bsp-desktop"

	# set up control file
	cat <<- EOF > "${destination}"/DEBIAN/control
		Package: armbian-bsp-desktop-${BOARD}
		Version: $REVISION
		Architecture: $ARCH
		Maintainer: $MAINTAINER <$MAINTAINERMAIL>
		Installed-Size: 1
		Section: xorg
		Priority: optional
		Provides: armbian-bsp-desktop, armbian-bsp-desktop-${BOARD}
		Depends: ${BSP_CLI_PACKAGE_NAME}
		Description: Armbian Board Specific Packages for desktop users using $ARCH ${BOARD} machines
	EOF

	# Recreating the DEBIAN/postinst file
	echo "#!/bin/sh -e" > "${destination}/DEBIAN/postinst"

	local aggregated_content=""
	aggregate_all_desktop "debian/armbian-bsp-desktop/postinst" $'\n'

	echo "${aggregated_content}" >> "${destination}/DEBIAN/postinst"
	echo "exit 0" >> "${destination}/DEBIAN/postinst"

	chmod 755 "${destination}"/DEBIAN/postinst

	# Armbian create_desktop_package scripts

	unset aggregated_content

	mkdir -p "${destination}"/etc/armbian

	local aggregated_content=""
	aggregate_all_desktop "debian/armbian-bsp-desktop/prepare.sh" $'\n'
	eval "${aggregated_content}"
	[[ $? -ne 0 ]] && display_alert "prepare.sh exec error" "" "wrn" # @TODO: this is a fantasy, error would be thrown in line above

	mkdir -p "${DEB_STORAGE}/${RELEASE}"
	cd "${destination}"
	cd ..
	fakeroot_dpkg_deb_build "${destination}" "${DEB_STORAGE}/${RELEASE}/${package_name}.deb"

	unset aggregated_content

}
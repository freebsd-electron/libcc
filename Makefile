# $FreeBSD$

PORTNAME=	libcc
PORTVERSION=	61.0.3163.100
CATEGORIES=	www
MASTER_SITES=	https://commondatastorage.googleapis.com/chromium-browser-official/:chromium
DISTFILES=	chromium-${PORTVERSION}.tar.xz:chromium

MAINTAINER=	pizzamig@FreeBSD.org
COMMENT=	Shared library build of Chromium's Content module'

BUILD_DEPENDS=	gn:devel/chromium-gn \
	bash:shells/bash \
	${PYTHON_PKGNAMEPREFIX}Jinja2>0:devel/py-Jinja2@${PY_FLAVOR} \
	${PYTHON_PKGNAMEPREFIX}ply>0:devel/py-ply@${PY_FLAVOR} \
	gperf:devel/gperf \
	yasm:devel/yasm \
	flock:sysutils/flock \
	node:www/node \
	${LOCALBASE}/include/linux/videodev2.h:multimedia/v4l_compat \
	${LOCALBASE}/share/usbids/usb.ids:misc/usbids \
	${PYTHON_PKGNAMEPREFIX}html5lib>0:www/py-html5lib@${PY_FLAVOR}

LIB_DEPENDS=	libspeechd.so:accessibility/speech-dispatcher \
		libsnappy.so:archivers/snappy \
		libFLAC.so:audio/flac \
		libspeex.so:audio/speex \
		libdbus-1.so:devel/dbus \
		libdbus-glib-1.so:devel/dbus-glib \
		libicuuc.so:devel/icu \
		libjsoncpp.so:devel/jsoncpp \
		libpci.so:devel/libpci \
		libnspr4.so:devel/nspr \
		libre2.so:devel/re2 \
		libcairo.so:graphics/cairo \
		libdrm.so:graphics/libdrm \
		libexif.so:graphics/libexif \
		libpng.so:graphics/png \
		libcups.so:print/cups \
		libharfbuzz.so:print/harfbuzz \
		libharfbuzz-icu.so:print/harfbuzz-icu \
		libgcrypt.so:security/libgcrypt \
		libgnome-keyring.so:security/libgnome-keyring \
		libnss3.so:security/nss \
		libexpat.so:textproc/expat2 \
		libxml2.so:textproc/libxml2 \
		libfontconfig.so:x11-fonts/fontconfig

RUN_DEPENDS=	xdg-open:devel/xdg-utils \
		droid-fonts-ttf>0:x11-fonts/droid-fonts-ttf

USES=	bison cpe desktop-file-utils jpeg ninja perl5 pkgconfig \
		python:2.7,build shebangfix tar:xz
	
USE_XORG=	x11 xcb xcomposite xcursor xext xdamage xfixes xi \
		xorgproto xrandr xrender xscrnsaver xtst
USE_GNOME=	atk dconf glib20 gtk30 libxml2 libxslt

USE_GITHUB=	nodefault
GH_ACCOUNT=	electron:libchromiumcontent yzgyyang:freebsdpatch piotrbulinski:boto freebsd-electron:chromiumpatches
GH_PROJECT=	libchromiumcontent:libchromiumcontent freebsd-libcc-release:freebsdpatch boto:boto chromium-patches:chromiumpatches
GH_TAGNAME=	0e760628832e77:libchromiumcontent 804fe7e:freebsdpatch 3265cad:boto 83d304d:chromiumpatches

.include "Makefile.inc"

GN_ARGS+=	clang_use_chrome_plugins=false \
		enable_nacl=false \
		enable_one_click_signin=true \
		enable_remoting=false \
		enable_webrtc=false \
		fieldtrial_testing_like_official_build=true \
		is_clang=true \
		toolkit_views=true \
		treat_warnings_as_errors=false \
		use_allocator="none" \
		use_allocator_shim=false \
		use_aura=true \
		use_cups=true \
		use_gtk3=true \
		use_lld=true \
		use_sysroot=false \
		use_system_libjpeg=true \
		use_system_sqlite=false   # chrome has additional patches

GN_BOOTSTRAP_FLAGS=	--no-clean --no-rebuild

post-extract:
	${MV} ${WRKSRC_libchromiumcontent} ${WRKSRC}
	${RMDIR} ${WRKSRC}/vendor/boto
	${MV} ${WRKSRC_boto} ${WRKSRC}/vendor/boto 
	${MV} ${WRKDIR}/chromium-${PORTVERSION} ${WRKSRC}/src
	${MKDIR} ${WRKSRC}/src/out/Release
	${LN} -s ${LOCALBASE}/bin/gn ${WRKSRC}/src/out/Release

pre-patch:
.for pf in ${PATCHES_CHROMIUM}
	( ${PATCH} -p0 -l -d ${WRKSRC}/src -i ${WRKDIR}/${pf} )
.endfor

post-patch:
	${PATCH} -p1 -l -d ${WRKSRC} < ${WRKSRC_freebsdpatch}/libchromiumcontent_111.diff
	${PATCH} -p1 -l -d ${WRKSRC} < ${WRKSRC_freebsdpatch}/libchromiumcontent_patches.diff
	${PATCH} -p0 -l -d ${WRKSRC}/src < ${WRKSRC_chromiumpatches}/extra-patch-clang
	${PATCH} -p1 -l -d ${WRKSRC}/src < ${WRKSRC_freebsdpatch}/chromiumv1.diff
	${PATCH} -p1 -l -d ${WRKSRC}/src < ${WRKSRC_freebsdpatch}/libchromiumcontent_bsd.diff
	${PATCH} -p1 -l -d ${WRKSRC}/src < ${WRKSRC_freebsdpatch}/libchromiumcontent_v8.diff

	${RM} ${WRKSRC}/patches/v8/025-cherry_pick_cc55747.patch*

pre-configure:
	# We used to remove bundled libraries to be sure that chromium uses
	# system libraries and not shipped ones.
	# cd ${WRKSRC} && ${PYTHON_CMD} \
	#./build/linux/unbundle/remove_bundled_libraries.py [list of preserved]
	cd ${WRKSRC}/src && ${SETENV} ${CONFIGURE_ENV} ${PYTHON_CMD} \
		./build/linux/unbundle/replace_gn_files.py --system-libraries \
		flac harfbuzz-ng libwebp libxml libxslt snappy yasm || ${FALSE}

do-configure:
	cd ${WRKSRC}/src && ${SETENV} ${CONFIGURE_ENV} gn \
		gen --args='${GN_ARGS}' out/${BUILDTYPE}

	# Setup nodejs dependency
	@${MKDIR} ${WRKSRC}/src/third_party/node/freebsd/node-freebsd-x64/bin
	${LN} -sf ${LOCALBASE}/bin/node ${WRKSRC}/src/third_party/node/freebsd/node-freebsd-x64/bin/node

do-build:
	( cd ${WRKSRC} && script/update -t x64 --skip_gclient )
	( cd ${WRKSRC} && script/build -c static_library -t x64 )
	( cd ${WRKSRC} && script/build -c ffmpeg -t x64 )
	( cd ${WRKSRC} && script/create-dist -c static_library -t x64 )
.include <bsd.port.mk>

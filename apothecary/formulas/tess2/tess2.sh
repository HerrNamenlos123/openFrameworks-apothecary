#!/usr/bin/env bash
#
# tess2
# Game and tools oriented refactored version of GLU tesselator
# https://code.google.com/p/libtess2/
#
# has no build system, only an old Xcode project
# we follow the Homebrew approach which is to use CMake via a custom CMakeLists.txt
# on ios, use some build scripts adapted from the Assimp project

# define the version
FORMULA_TYPES=( "osx" "vs" "emscripten" "ios" "tvos" "android" "linux" "linux64" "linuxarmv6l" "linuxarmv7l" "linuxaarch64" "msys2" )

# define the version
VER=1.0.2

# tools for git use
GIT_URL=https://github.com/memononen/libtess2
GIT_TAG=master

CSTANDARD=c11 # c89 | c99 | c11 | gnu11
CPPSTANDARD=c++11 # c89 | c99 | c11 | gnu11
COMPILER_CTYPE=clang # clang, gcc
COMPILER_CPPTYPE=clang++ # clang, gcc
STDLIB=libc++



# download the source code and unpack it into LIB_NAME
function download() {
	. "$DOWNLOADER_SCRIPT"
	downloader $GIT_URL/archive/refs/tags/v$VER.tar.gz
	tar -xzf v$VER.tar.gz
	mv libtess2-$VER tess2
	rm v$VER.tar.gz

	# check if the patch was applied, if not then patch

	cd tess2 
	patch -p1 -u -N  < $FORMULA_DIR/tess2.patch
	cd ..
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	# copy in build script and CMake toolchains adapted from Assimp
	if [ "$TYPE" == "osx" ] ; then
		mkdir -p build
	fi
}

# executed inside the lib src dir
function build() {

	if [ "$TYPE" == "osx" ] ; then
	    # use CMake for the build using CMakeLists.txt from HomeBrew since the original source doesn't have one
	    # see : https://github.com/mxcl/homebrew/pull/19634/files
	    cp -v $FORMULA_DIR/CMakeLists.txt .

		unset CFLAGS CPPFLAGS LINKFLAGS CXXFLAGS LDFLAGS
		rm -f CMakeCache.txt

		STD_LIB_FLAGS="-stdlib=libc++"
		OPTIM_FLAGS="-O3"				 # 	choose "fastest" optimisation

		export CFLAGS="-arch arm64 -arch x86_64 $OPTIM_FLAGS -DNDEBUG -fPIC"
		export CPPFLAGS=$CFLAGS
		export LINKFLAGS="$CFLAGS $STD_LIB_FLAGS"
		export LDFLAGS="$LINKFLAGS"
		export CXXFLAGS=$CPPFLAGS

		mkdir -p build
		cd build
		cmake -G 'Unix Makefiles' -DCMAKE_OSX_DEPLOYMENT_TARGET=${OSX_MIN_SDK_VER} \
				..
		make clean
		make -j${PARALLEL_MAKE}

	elif [ "$TYPE" == "vs" ] ; then
		cp -v $FORMULA_DIR/CMakeLists.txt .
		echo "building tess2 $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
	    echo "--------------------"
	    GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"
	    mkdir -p "build_${TYPE}_${ARCH}"
	    cd "build_${TYPE}_${ARCH}"
	    DEFS="-DLIBRARY_SUFFIX=${ARCH} \
	        -DCMAKE_BUILD_TYPE=Release \
	        -DCMAKE_C_STANDARD=17 \
	        -DCMAKE_CXX_STANDARD=17 \
	        -DCMAKE_CXX_STANDARD_REQUIRED=ON \
	        -DCMAKE_CXX_EXTENSIONS=OFF
	        -DBUILD_SHARED_LIBS=OFF \
	        -DCMAKE_INSTALL_PREFIX=Release \
	        -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
	        -DCMAKE_INSTALL_INCLUDEDIR=include"         
	    cmake .. ${DEFS} \
	        -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1" \
	        -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
	        -DCMAKE_BUILD_TYPE=Release \
	        -DCMAKE_INSTALL_LIBDIR="lib" \
	        ${CMAKE_WIN_SDK} \
	        -DCMAKE_CXX_FLAGS=-DNDEBUG \
	        -DCMAKE_C_FLAGS=-DNDEBUG \
	        -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
	        -A "${PLATFORM}" \
	        -G "${GENERATOR_NAME}"
	    cmake --build . --config Release --target install
	    cd ..
	elif [[ "$TYPE" == "ios" || "${TYPE}" == "tvos" ]] ; then
	    cp -v $FORMULA_DIR/CMakeLists.txt .
		local IOS_ARCHS
        if [ "${TYPE}" == "tvos" ]; then
            IOS_ARCHS="x86_64 arm64"
        elif [ "$TYPE" == "ios" ]; then
            IOS_ARCHS="x86_64 armv7 arm64" #armv7s
        fi

		SDKVERSION=`xcrun -sdk iphoneos --show-sdk-version`
		set -e
		CURRENTPATH=`pwd`

		DEVELOPER=$XCODE_DEV_ROOT
		TOOLCHAIN=${DEVELOPER}/Toolchains/XcodeDefault.xctoolchain

		mkdir -p "builddir/$TYPE"

		# Validate environment
		case $XCODE_DEV_ROOT in
		     *\ * )
		           echo "Your Xcode path contains whitespaces, which is not supported."
		           exit 1
		          ;;
		esac
		case $CURRENTPATH in
		     *\ * )
		           echo "Your path contains whitespaces, which is not supported by 'make install'."
		           exit 1
		          ;;
		esac

		export CC=$TOOLCHAIN/usr/bin/$COMPILER_CTYPE
		export CPP=$TOOLCHAIN/usr/bin/$COMPILER_CPPTYPE
		export CXX=$TOOLCHAIN/usr/bin/$COMPILER_CTYPE
		export CXXCPP=$TOOLCHAIN/usr/bin/$COMPILER_CPPTYPE

		export LD=$TOOLCHAIN/usr/bin/ld
		export AR=$TOOLCHAIN/usr/bin/ar
		export AS=$TOOLCHAIN/usr/bin/as
		export NM=$$TOOLCHAIN/usr/bin/nm
		export RANLIB=$TOOLCHAIN/usr/bin/ranlib

		SDKVERSION=""
        if [ "${TYPE}" == "tvos" ]; then
            SDKVERSION=`xcrun -sdk appletvos --show-sdk-version`
        elif [ "$TYPE" == "ios" ]; then
            SDKVERSION=`xcrun -sdk iphoneos --show-sdk-version`
        fi

		EXTRA_LINK_FLAGS="-stdlib=libc++ -Os -fPIC"
		EXTRA_FLAGS="$EXTRA_LINK_FLAGS -fvisibility-inlines-hidden"

		# loop through architectures! yay for loops!
		for IOS_ARCH in ${IOS_ARCHS}
		do

			unset CFLAGS CPPFLAGS LINKFLAGS CXXFLAGS LDFLAGS
            
			rm -f CMakeCache.txt
			set +e

			if [[ "${IOS_ARCH}" == "i386" || "${IOS_ARCH}" == "x86_64" ]];
			then
                if [ "${TYPE}" == "tvos" ]; then
                    PLATFORM="AppleTVSimulator"
                elif [ "$TYPE" == "ios" ]; then
                    PLATFORM="iPhoneSimulator"
                fi
			else
                if [ "${TYPE}" == "tvos" ]; then
                    PLATFORM="AppleTVOS"
                elif [ "$TYPE" == "ios" ]; then
                    PLATFORM="iPhoneOS"
                fi
			fi

			export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
			export CROSS_SDK="${PLATFORM}${SDKVERSION}.sdk"
			export BUILD_TOOLS="${DEVELOPER}"

			MIN_IOS_VERSION=$IOS_MIN_SDK_VER
		    if [[ "${IOS_ARCH}" == "arm64" || "${IOS_ARCH}" == "x86_64" ]]; then
		    	MIN_IOS_VERSION=7.0 # 7.0 as this is the minimum for these architectures
		    elif [ "${IOS_ARCH}" == "i386" ]; then
		    	MIN_IOS_VERSION=7.0
		    fi

            if [ "${TYPE}" == "tvos" ]; then
    		    MIN_TYPE=-mtvos-version-min=
    		    if [[ "${IOS_ARCH}" == "i386" || "${IOS_ARCH}" == "x86_64" ]]; then
    		    	MIN_TYPE=-mtvos-simulator-version-min=
    		    fi
            elif [ "$TYPE" == "ios" ]; then
                MIN_TYPE=-miphoneos-version-min=
                if [[ "${IOS_ARCH}" == "i386" || "${IOS_ARCH}" == "x86_64" ]]; then
                    MIN_TYPE=-mios-simulator-version-min=
                fi
            fi

            BITCODE=""
            if [[ "$TYPE" == "tvos" ]] || [[ "${IOS_ARCH}" == "arm64" ]]; then
                BITCODE=-fembed-bitcode;
                MIN_IOS_VERSION=13.0
            fi


			export CFLAGS="-arch $IOS_ARCH $BITCODE -DNDEBUG -pipe -no-cpp-precomp -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} $MIN_TYPE$MIN_IOS_VERSION -I${CROSS_TOP}/SDKs/${CROSS_SDK}/usr/include/"

			export CPPFLAGS=$CFLAGS
			export LINKFLAGS="$CFLAGS $EXTRA_LINK_FLAGS "
			export LDFLAGS="-L${CROSS_TOP}/SDKs/${CROSS_SDK}/usr/lib/ $LINKFLAGS -std=c++17 -stdlib=libc++"
			export CXXFLAGS="$CFLAGS $EXTRA_FLAGS"

			mkdir -p "$CURRENTPATH/builddir/$TYPE/$IOS_ARCH"
			LOG="$CURRENTPATH/builddir/$TYPE/$IOS_ARCH/build-tess2-${VER}-$IOS_ARCH.log"
			echo "-----------------"
			echo "Building tess2-${VER} for ${PLATFORM} ${SDKVERSION} ${IOS_ARCH} : iOS Minimum=$MIN_IOS_VERSION"
			set +e

			echo "Running make for ${IOS_ARCH}"
			echo "Please stand by..."

			cmake -G 'Unix Makefiles' -DCMAKE_OSX_SYSROOT="/" -DCMAKE_OSX_DEPLOYMENT_TARGET=""  #need these flags because newer cmake tries to be smart and breaks simulator builds 
			make clean >> "${LOG}" 2>&1
			make -j${PARALLEL_MAKE} >> "${LOG}" 2>&1

			if [ $? != 0 ];
		    then
		    	tail -n 100 "${LOG}"
		    	echo "Problem while make - Please check ${LOG}"
		    	exit 1
		    else
		    	echo "Make Successful for ${IOS_ARCH}"
		    fi

			mv libtess2.a builddir/$TYPE/libtess2-$IOS_ARCH.a

		done

		echo "-----------------"
		echo `pwd`
		echo "Finished for all architectures."
		mkdir -p "$CURRENTPATH/builddir/$TYPE/"

		mkdir -p "lib/$TYPE"

		# link into universal lib
		echo "Running lipo to create fat lib"
		echo "Please stand by..."

		if [[ "${TYPE}" == "tvos" ]]; then
			lipo -create -arch arm64 builddir/$TYPE/libtess2-arm64.a \
			 	-arch x86_64 builddir/$TYPE/libtess2-x86_64.a \
			 	-output builddir/$TYPE/libtess2.a
		 elif [[ "$TYPE" == "ios" ]]; then
            # builddir/$TYPE/libtess2-armv7s.a
            lipo -create -arch armv7 builddir/$TYPE/libtess2-armv7.a \
			 	-arch arm64 builddir/$TYPE/libtess2-arm64.a \
			 	-arch x86_64 builddir/$TYPE/libtess2-x86_64.a \
			 	-output builddir/$TYPE/libtess2.a
		fi

		if [ $? != 0 ];
		then
			tail -n 10 "${LOG}"
		    echo "Problem while creating fat lib with lipo - Please check ${LOG}"
		    exit 1
		else
		   	echo "Lipo Successful."
		fi

		mv builddir/$TYPE/libtess2.a lib/$TYPE/libtess2.a
		lipo -info lib/$TYPE/libtess2.a

		if [[ "$TYPE" == "ios" ]]; then
			echo "--------------------"
			echo "Stripping any lingering symbols"

			SLOG="$CURRENTPATH/lib/$TYPE/tess2-stripping.log"

			strip -x lib/$TYPE/libtess2.a >> "${SLOG}" 2>&1
			if [ $? != 0 ];
			then
				tail -n 100 "${SLOG}"
			    echo "Problem while stripping lib - Please check ${SLOG}"
			    exit 1
			else
			    echo "Strip Successful for ${SLOG}"
			fi
		fi

		echo "--------------------"
		echo "Build Successful for Tess2 $TYPE"
		unset SDKROOT CFLAGS CC LD CPP CXX AR AS NM CXXCPP RANLIB LDFLAGS CPPFLAGS CXXFLAGS LINKFLAGS
		unset CROSS_TOP CROSS_SDK BUILD_TOOLS

	elif [ "$TYPE" == "android" ] ; then
 
        # setup android paths / variables
	    source ../../android_configure.sh $ABI cmake
        
		cp -v $FORMULA_DIR/CMakeLists.txt .

		mkdir -p "build_$ABI"
		cd "./build_$ABI"
		export CFLAGS=""
        export CMAKE_CFLAGS="$CFLAGS"
        
        export CPPFLAGS=""
        export CMAKE_LDFLAGS="$LDFLAGS"
       	export LDFLAGS=""
        cmake -D CMAKE_TOOLCHAIN_FILE=${NDK_ROOT}/build/cmake/android.toolchain.cmake \
        	-D CMAKE_OSX_SYSROOT:PATH==${SYSROOT} \
      		-D CMAKE_C_COMPILER==${CC} \
     	 	-D CMAKE_CXX_COMPILER_RANLIB=${RANLIB} \
     	 	-D CMAKE_C_COMPILER_RANLIB=${RANLIB} \
     	 	-D CMAKE_CXX_COMPILER_AR=${AR} \
     	 	-D CMAKE_C_COMPILER_AR=${AR} \
     	 	-D CMAKE_C_COMPILER=${CC} \
     	 	-D CMAKE_CXX_COMPILER=${CXX} \
     	 	-D CMAKE_C_FLAGS=${CFLAGS} \
     	 	-D CMAKE_CXX_FLAGS=${CPPFLAGS} \
        	-D ANDROID_ABI=${ABI} \
        	-D CMAKE_CXX_STANDARD_LIBRARIES=${LIBS} \
        	-D CMAKE_C_STANDARD_LIBRARIES=${LIBS} \
        	-D CMAKE_STATIC_LINKER_FLAGS=${LDFLAGS} \
        	-D ANDROID_NATIVE_API_LEVEL=${ANDROID_API} \
        	-D ANDROID_TOOLCHAIN=clang \
        	-DCMAKE_SYSROOT=$SYSROOT \
            -DANDROID_NDK=$NDK_ROOT \
            -DANDROID_ABI=$ABI \
            -DANDROID_STL=c++_shared \
        	-DCMAKE_C_STANDARD=17 \
        	-DCMAKE_CXX_STANDARD=17 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
        	-G 'Unix Makefiles' ..
		make -j${PARALLEL_MAKE} VERBOSE=1
		cd ..

	elif [ "$TYPE" == "emscripten" ] ; then
    	cp -v $FORMULA_DIR/CMakeLists.txt .
    	mkdir -p build
    	cd build
    	emcmake cmake .. -DCMAKE_CXX_FLAGS="-DNDEBUG -pthread" -DCMAKE_C_FLAGS="-DNDEBUG -pthread"
    	emmake make -j${PARALLEL_MAKE}
	elif [ "$TYPE" == "linux64" ] || [ "$TYPE" == "linux" ] || [ "$TYPE" == "msys2" ]; then
	    mkdir -p build
	    cd build
	    cp -v $FORMULA_DIR/Makefile .
	    cp -v $FORMULA_DIR/tess2.make .
	    make config=release tess2
	elif [ "$TYPE" == "linuxarmv6l" ] || [ "$TYPE" == "linuxarmv7l" ] || [ "$TYPE" == "linuxaarch64" ]; then
        if [ $CROSSCOMPILING -eq 1 ]; then
            source ../../${TYPE}_configure.sh
        fi
	    mkdir -p build
	    cd build
	    cp -v $FORMULA_DIR/Makefile .
	    cp -v $FORMULA_DIR/tess2.make .
	    make config=release tess2
	    cd ..
	    mkdir -p build/$TYPE
	    mv build/libtess2.a build/$TYPE
	else
		mkdir -p build/$TYPE
		cd build/$TYPE
		cmake -G "Unix Makefiles" -DCMAKE_CXX_COMPILER=/mingw32/bin/g++.exe -DCMAKE_C_COMPILER=/mingw32/bin/gcc.exe -DCMAKE_CXX_FLAGS=-DNDEBUG -DCMAKE_C_FLAGS=-DNDEBUG ../../
		make
	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {

	# headers
	rm -rf $1/include
	mkdir -p $1/include
	cp -Rv Include/* $1/include/

	# lib
	mkdir -p $1/lib/$TYPE
	if [ "$TYPE" == "vs" ] ; then
		mkdir -p $1/lib/$TYPE/$PLATFORM/
		cp -Rv "build_${TYPE}_${ARCH}/Release/include/" $1/ 
    	cp -f "build_${TYPE}_${ARCH}/Release/lib/tess2.lib" $1/lib/$TYPE/$PLATFORM/tess2.lib
	elif [[ "$TYPE" == "ios" || "$TYPE" == "tvos" ]]; then
		cp -v lib/$TYPE/libtess2.a $1/lib/$TYPE/tess2.a

	elif [ "$TYPE" == "osx" ]; then
		cp -v build/libtess2.a $1/lib/$TYPE/tess2.a

	elif [ "$TYPE" == "emscripten" ]; then
		cp -v build/libtess2.a $1/lib/$TYPE/libtess2.a

	elif [ "$TYPE" == "linux64" ] || [ "$TYPE" == "linux" ] || [ "$TYPE" == "msys2" ]; then
		cp -v build/libtess2.a $1/lib/$TYPE/libtess2.a

	elif [ "$TYPE" == "android" ]; then
	    rm -rf $1/lib/$TYPE/$ABI
	    mkdir -p $1/lib/$TYPE/$ABI
		#cp -v build/$TYPE/$ABI/libtess2.a $1/lib/$TYPE/$ABI/libtess2.a #make
		cp -v build_$ABI/libtess2.a $1/lib/$TYPE/$ABI/libtess2.a
	else
		cp -v build/$TYPE/libtess2.a $1/lib/$TYPE/libtess2.a
	fi

	# copy license files
	if [ -d "$1/license" ]; then
        rm -rf $1/license
    fi
	mkdir -p $1/license
	cp -v LICENSE.txt $1/license/
}

# executed inside the lib src dir
function clean() {
	if [ "$TYPE" == "vs" ] ; then
		rm -f CMakeCache.txt *.lib
		if [ -d "build_${TYPE}_${ARCH}" ]; then
		    # Delete the folder and its contents
		    rm -r build_${TYPE}_${ARCH}	    
		fi
	elif [ "$TYPE" == "android" ] ; then
		rm -f CMakeCache.txt *.a *.o
		rm -f builddir/$TYPE
		rm -f builddir
		rm -f lib
	elif [[ "$TYPE" == "ios" || "$TYPE" == "tvos" ]]; then
		make clean
		rm -f CMakeCache.txt *.a *.lib
		rm -f builddir/$TYPE
		rm -f builddir
		rm -f lib
	else
		make clean
		rm -f CMakeCache.txt *.a *.lib
	fi
}

function save() {
    . "$SAVE_SCRIPT" 
    savestatus ${TYPE} "tess2" ${ARCH} ${VER} true "${SAVE_FILE}"
}

function load() {
    . "$LOAD_SCRIPT"
    if loadsave ${TYPE} "tess2" ${ARCH} ${VER} "${SAVE_FILE}"; then
      return 0;
    else
      return 1;
    fi
}

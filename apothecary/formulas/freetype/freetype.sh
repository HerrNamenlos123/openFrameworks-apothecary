#!/usr/bin/env bash
#
# Free Type
# cross platform ttf/optf font loder
# http://freetype.org/
#
# an autotools project

FORMULA_TYPES=( "osx" "vs" "ios" "tvos" "android" "emscripten" )

FORMULA_DEPENDS=( "zlib" "libpng" )

# define the version
VER=2.13.2
FVER=213

GIT_VER=VER-2-13-2

# tools for git use
GIT_URL=https://git.savannah.gnu.org/r/freetype/freetype2.git
GIT_TAG=VER-2-13
URL=http://download.savannah.nongnu.org/releases/freetype
MIRROR_URL=https://mirror.ossplanet.net/nongnu/freetype
GIT_HUB=https://github.com/freetype/freetype/tags
GIT_HUB_URL=https://github.com/freetype/freetype/archive/refs/tags/VER-2-13-2.tar.gz



# download the source code and unpack it into LIB_NAME
function download() {
	echo "Downloading freetype-$GIT_VER"

	. "$DOWNLOADER_SCRIPT"
	downloader $GIT_HUB_URL
	
	tar -xzf $GIT_VER.tar.gz
	mv freetype-$GIT_VER freetype
	rm $GIT_VER*.tar.gz
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	mkdir -p lib/$TYPE

	apothecaryDependencies download
    
    apothecaryDepend prepare zlib
    apothecaryDepend build zlib
    apothecaryDepend copy zlib
}

# executed inside the lib src dir
function build() {
	LIBS_ROOT=$(realpath $LIBS_DIR)
	if [ "$TYPE" == "osx" ] ; then
		
		mkdir -p "build_${TYPE}_${PLATFORM}"
		cd "build_${TYPE}_${PLATFORM}"
		rm -f CMakeCache.txt *.a *.o

		ZLIB_ROOT="$LIBS_ROOT/zlib/"
		ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
		ZLIB_LIBRARY="$LIBS_ROOT/zlib/$TYPE/$PLATFORM/zlib.a"

		LIBPNG_ROOT="$LIBS_ROOT/libpng/"
        LIBPNG_INCLUDE_DIR="$LIBS_ROOT/libpng/include"
        LIBPNG_LIBRARY="$LIBS_ROOT/libpng/lib/$TYPE/$PLATFORM/libpng.a" 

		DEFS="-DCMAKE_BUILD_TYPE=Release \
		    -DCMAKE_C_STANDARD=17 \
		    -DCMAKE_CXX_STANDARD=17 \
		    -DCMAKE_CXX_STANDARD_REQUIRED=ON \
		    -DCMAKE_CXX_EXTENSIONS=OFF \
		    -DZLIB_ROOT=${ZLIB_ROOT} \
		    -DZLIB_LIBRARY=${ZLIB_INCLUDE_DIR} \
		    -DZLIB_INCLUDE_DIRS=${ZLIB_LIBRARY} \
            -DPNG_INCLUDE_DIR=${LIBPNG_INCLUDE_DIR} \
            -DPNG_LIBRARY=${LIBPNG_LIBRARY} \
            -DPNG_ROOT=${LIBPNG_ROOT} 
            -DFT_DISABLE_ZLIB=OFF \
            -DFT_DISABLE_BZIP2=TRUE \
            -DFT_DISABLE_PNG=OFF \
            -DFT_DISABLE_HARFBUZZ=TRUE \
            -DFT_DISABLE_BROTLI=TRUE \
		    -DBUILD_SHARED_LIBS=OFF \
		    -DENABLE_STATIC=ON \
			-DCMAKE_INSTALL_PREFIX=Release \
			-DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
			-DCMAKE_INSTALL_INCLUDEDIR=include"

			cmake .. ${DEFS} \
				-DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/ios.toolchain.cmake \
				-DPLATFORM=$PLATFORM \
				-DENABLE_BITCODE=OFF \
				-DENABLE_ARC=OFF \
				-DENABLE_VISIBILITY=OFF \
            	-DCMAKE_POSITION_INDEPENDENT_CODE=TRUE
					
		cmake --build . --config Release --target install
		cd ..	

	elif [ "$TYPE" == "vs" ] ; then
		
		echo "building $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
        echo "--------------------"
        GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"  

        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.lib" 

        LIBPNG_ROOT="$LIBS_ROOT/libpng/"
        LIBPNG_INCLUDE_DIR="$LIBS_ROOT/libpng/include"
        LIBPNG_LIBRARY="$LIBS_ROOT/libpng/lib/$TYPE/$PLATFORM/libpng.lib" 

        mkdir -p "build_${TYPE}_${ARCH}"
        cd "build_${TYPE}_${ARCH}"
        rm -f CMakeCache.txt *.a *.o

        NO_LINK_BROTLI=OFF

        if [ "$PLATFORM" == "ARM64EC" ] ; then
       		NO_LINK_BROTLI=ON
      	fi

        DEFS="
        	-DCMAKE_C_STANDARD=17 \
            -DCMAKE_CXX_STANDARD=17 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DFT_DISABLE_ZLIB=OFF \
            -DFT_DISABLE_BZIP2=TRUE \
            -DFT_DISABLE_PNG=OFF \
            -DFT_DISABLE_HARFBUZZ=TRUE \
            -DFT_DISABLE_BROTLI=${NO_LINK_BROTLI} \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
		    -DCMAKE_ARCHIVE_OUTPUT_DIRECTORY_RELEASE=lib \
		    -DCMAKE_LIBRARY_OUTPUT_DIRECTORY_RELEASE=lib \
		    -DCMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE=bin \
		    -DCMAKE_ARCHIVE_OUTPUT_DIRECTORY_DEBUG=lib \
		    -DCMAKE_LIBRARY_OUTPUT_DIRECTORY_DEBUG=lib \
		    -DCMAKE_RUNTIME_OUTPUT_DIRECTORY_DEBUG=bin"

		 env CXXFLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE}"

         cmake .. ${DEFS} \
            -D CMAKE_VERBOSE_MAKEFILE=ON \
		    -D BUILD_SHARED_LIBS=OFF \
		    ${CMAKE_WIN_SDK} \
		    -A "${PLATFORM}" \
            -G "${GENERATOR_NAME}" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=Release \
            -UCMAKE_CXX_FLAGS \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} " \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} " \
            -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DPNG_PNG_INCLUDE_DIR=${LIBPNG_INCLUDE_DIR} \
            -DPNG_LIBRARY=${LIBPNG_LIBRARY} \
            -DPNG_ROOT=${LIBPNG_ROOT} 
        cmake --build . --config Release --target install   

        env CXXFLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG}"
        cmake .. ${DEFS} \
            -D CMAKE_VERBOSE_MAKEFILE=ON \
		    -D BUILD_SHARED_LIBS=OFF \
		    ${CMAKE_WIN_SDK} \
		    -A "${PLATFORM}" \
            -G "${GENERATOR_NAME}" \
            -DCMAKE_BUILD_TYPE=Debug \
            -DCMAKE_INSTALL_PREFIX=Debug \
            -UCMAKE_CXX_FLAGS \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG} " \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG} " \
            -DCMAKE_CXX_FLAGS_DEBUG="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS_DEBUG="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG} ${EXCEPTION_FLAGS}" \
            -DCMAKE_PREFIX_PATH="${ZLIB_ROOT}" \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DPNG_PNG_INCLUDE_DIR=${LIBPNG_INCLUDE_DIR} \
            -DPNG_LIBRARY=${LIBPNG_LIBRARY} \
            -DPNG_ROOT=${LIBPNG_ROOT} 
        cmake --build . --config Debug --target install 
        unset CXXFLAGS

        cd ..

	elif [ "$TYPE" == "msys2" ] ; then
		# configure with arch
		if [ $ARCH ==  32 ] ; then
			./configure CFLAGS="-arch i386" --without-bzip2 --without-brotli --with-harfbuzz=no
		elif [ $ARCH == 64 ] ; then
			./configure CFLAGS="-arch x86_64" --without-bzip2 --without-brotli --with-harfbuzz=no
		fi

		make clean;
		make -j${PARALLEL_MAKE}

	elif [[ "$TYPE" == "ios" || "${TYPE}" == "tvos" ]] ; then

		mkdir -p "build_${TYPE}_${PLATFORM}"
		cd "build_${TYPE}_${PLATFORM}"
		rm -f CMakeCache.txt *.a *.o

		ZLIB_ROOT="$LIBS_ROOT/zlib/"
		ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
		ZLIB_LIBRARY="$LIBS_ROOT/zlib/$TYPE/$PLATFORM/zlib.a"

		DEFS="-DCMAKE_BUILD_TYPE=Release \
		    -DCMAKE_C_STANDARD=17 \
		    -DCMAKE_CXX_STANDARD=17 \
		    -DCMAKE_CXX_STANDARD_REQUIRED=ON \
		    -DCMAKE_CXX_EXTENSIONS=OFF \
		    -DZLIB_ROOT=${ZLIB_ROOT} \
		    -DZLIB_LIBRARY=${ZLIB_INCLUDE_DIR} \
		    -DZLIB_INCLUDE_DIRS=${ZLIB_LIBRARY} \
            -DFT_DISABLE_ZLIB=OFF \
            -DFT_DISABLE_BZIP2=TRUE \
            -DFT_DISABLE_PNG=OFF \
            -DFT_DISABLE_HARFBUZZ=TRUE \
            -DFT_DISABLE_BROTLI=TRUE \
		    -DBUILD_SHARED_LIBS=OFF \
		    -DENABLE_STATIC=ON \
			-DCMAKE_INSTALL_PREFIX=Release \
			-DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
			-DCMAKE_INSTALL_INCLUDEDIR=include"

			cmake .. ${DEFS} \
				-DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/ios.toolchain.cmake \
				-DPLATFORM=$PLATFORM \
				-DENABLE_BITCODE=OFF \
				-DENABLE_ARC=OFF \
				-DENABLE_VISIBILITY=OFF 
					
		cmake --build . --config Release --target install
		cd ..

	elif [ "$TYPE" == "android" ] ; then

        source ../../android_configure.sh $ABI cmake
        rm -rf "build_${ABI}/"
        rm -rf "build_${ABI}/CMakeCache.txt"
		mkdir -p "build_$ABI"
		cd "./build_$ABI"
		CFLAGS=""
        export CMAKE_CFLAGS="$CFLAGS"
        #export CFLAGS=""
        export CPPFLAGS=""
        export CMAKE_LDFLAGS="$LDFLAGS"
       	export LDFLAGS=""

        cmake -D CMAKE_TOOLCHAIN_FILE=${NDK_ROOT}/build/cmake/android.toolchain.cmake \
        	-D CMAKE_OSX_SYSROOT:PATH=${SYSROOT} \
      		-D CMAKE_C_COMPILER=${CC} \
     	 	-D CMAKE_CXX_COMPILER_RANLIB=${RANLIB} \
     	 	-D CMAKE_C_COMPILER_RANLIB=${RANLIB} \
     	 	-D CMAKE_CXX_COMPILER_AR=${AR} \
     	 	-D CMAKE_C_COMPILER_AR=${AR} \
     	 	-D CMAKE_C_COMPILER=${CC} \
     	 	-D CMAKE_CXX_COMPILER=${CXX} \
     	 	-D CMAKE_C_FLAGS=${CFLAGS} \
     	 	-D CMAKE_CXX_FLAGS=${CXXFLAGS} \
     	 	-DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
        	-D ANDROID_ABI=${ABI} \
        	-D CMAKE_CXX_STANDARD_LIBRARIES=${LIBS} \
        	-D CMAKE_C_STANDARD_LIBRARIES=${LIBS} \
        	-D CMAKE_STATIC_LINKER_FLAGS=${LDFLAGS} \
        	-D ANDROID_NATIVE_API_LEVEL=${ANDROID_API} \
        	-D ANDROID_TOOLCHAIN=clang \
        	-D CMAKE_BUILD_TYPE=Release \
        	-D FT_REQUIRE_HARFBUZZ=FALSE \
        	-D FT_REQUIRE_BROTLI=FALSE \
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

	elif [ "$TYPE" == "emscripten" ]; then

		ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/zlib.a"

        LIBPNG_ROOT="$LIBS_ROOT/libpng/"
        LIBPNG_INCLUDE_DIR="$LIBS_ROOT/libpng/include"
        LIBPNG_LIBRARY="$LIBS_ROOT/libpng/lib/$TYPE/libpng.a" 

        mkdir -p build_$TYPE
        cd build_$TYPE
        $EMSDK/upstream/emscripten/emcmake cmake .. \
            -B . \
            -DCMAKE_C_FLAGS="-O3 -DNDEBUG -DUSE_PTHREADS=1 -I${ZLIB_INCLUDE_DIR}" \
            -DCMAKE_CXX_FLAGS="-O3 -DNDEBUG -DUSE_PTHREADS=1 -I${ZLIB_INCLUDE_DIR}" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_C_STANDARD=17 \
            -DCMAKE_CXX_STANDARD=17 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DBUILD_SHARED_LIBS=OFF \
            -DFT_DISABLE_ZLIB=OFF \
            -DFT_DISABLE_BZIP2=ON \
            -DFT_DISABLE_PNG=ON \
            -DFT_DISABLE_HARFBUZZ=ON \
            -DFT_DISABLE_BROTLI=ON \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DPNG_INCLUDE_DIR=${LIBPNG_INCLUDE_DIR} \
            -DPNG_LIBRARY=${LIBPNG_LIBRARY} \
            -DPNG_ROOT=${LIBPNG_ROOT}

        cmake --build . --config Release
        cd ..
	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
    #remove old include files if they exist
    if [ -d "$1/include" ]; then
        rm -rf $1/include
    fi

	# copy headers
	mkdir -p $1/include/freetype2/

	# copy files from the build root
	cp -Rv include/* $1/include/freetype2/

	# older versions before 2.5.x
	#mkdir -p $1/include/freetype2/freetype/config
	#cp -Rv include/* $1/include/freetype2/freetype
	#cp -Rv include/ft2build.h $1/include/

	# copy lib
	mkdir -p $1/lib/$TYPE
	if [[ "$TYPE" == "osx" || "$TYPE" == "ios" || "$TYPE" == "tvos" ]] ; then
		mkdir -p $1/lib/$TYPE/$PLATFORM/
		cp -Rv "build_${TYPE}_${PLATFORM}/Release/include" $1/include
		cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libfreetype.a" $1/lib/$TYPE/$PLATFORM/libfreetype.a
	elif [ "$TYPE" == "vs" ] ; then
		mkdir -p $1/lib/$TYPE/$PLATFORM/
		cp -RvT "build_${TYPE}_${ARCH}/Release/include" $1/include
        cp -v "build_${TYPE}_${ARCH}/lib/"*.lib $1/lib/$TYPE/$PLATFORM/
        # cp -v "build_${TYPE}_${ARCH}/lib/"*.pdb $1/lib/$TYPE/$PLATFORM/

	elif [ "$TYPE" == "msys2" ] ; then
		# cp -v lib/$TYPE/libfreetype.a $1/lib/$TYPE/libfreetype.a
		echoWarning "TODO: copy msys2 lib"
	elif [ "$TYPE" == "android" ] ; then
	    rm -rf $1/lib/$TYPE/$ABI
        mkdir -p $1/lib/$TYPE/$ABI
	    cp -v build_$ABI/libfreetype.a $1/lib/$TYPE/$ABI/libfreetype.a
	elif [ "$TYPE" == "emscripten" ] ; then
		cp -v "build_${TYPE}/libfreetype.a" $1/lib/$TYPE/libfreetype.a
	fi

	# copy license files
	if [ -d "$1/license" ]; then
        rm -rf $1/license
    fi
	mkdir -p $1/license
	cp -v LICENSE.TXT $1/license/LICENSE
	cp -v docs/FTL.TXT $1/license/
	cp -v docs/GPLv2.TXT $1/license/
}

# executed inside the lib src dir
function clean() {

	if [ "$TYPE" == "vs" ] ; then
		rm -f CMakeCache.txt *.a *.o *.lib
		rm -f "build_${TYPE}_${PLATFORM}"
	elif [ "$TYPE" == "android" ] ; then
		rm -f CMakeCache.txt *.a *.o
		rm -f builddir/$TYPE
		rm -f builddir
		rm -f lib
	elif [[ "$TYPE" == "ios" || "$TYPE" == "tvos" || "$TYPE" == "osx" ]]; then
		make clean
		rm -f CMakeCache.txt *.a *.o
		rm -f "build_${TYPE}_${PLATFORM}"
	else
		rm -f CMakeCache.txt *.a *.o *.lib
		make clean
	fi
}

function save() {
    . "$SAVE_SCRIPT" 
    savestatus ${TYPE} "freetype" ${ARCH} ${VER} true "${SAVE_FILE}"
}

function load() {
    . "$LOAD_SCRIPT"
    if loadsave ${TYPE} "freetype" ${ARCH} ${VER} "${SAVE_FILE}"; then
      return 0;
    else
      return 1;
    fi
}

# Install script for directory: /mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf

# Set the install prefix
if(NOT DEFINED CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX "/usr/local")
endif()
string(REGEX REPLACE "/$" "" CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")

# Set the install configuration name.
if(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)
  if(BUILD_TYPE)
    string(REGEX REPLACE "^[^A-Za-z0-9_]+" ""
           CMAKE_INSTALL_CONFIG_NAME "${BUILD_TYPE}")
  else()
    set(CMAKE_INSTALL_CONFIG_NAME "Release")
  endif()
  message(STATUS "Install configuration: \"${CMAKE_INSTALL_CONFIG_NAME}\"")
endif()

# Set the component getting installed.
if(NOT CMAKE_INSTALL_COMPONENT)
  if(COMPONENT)
    message(STATUS "Install component: \"${COMPONENT}\"")
    set(CMAKE_INSTALL_COMPONENT "${COMPONENT}")
  else()
    set(CMAKE_INSTALL_COMPONENT)
  endif()
endif()

# Install shared libraries without execute permission?
if(NOT DEFINED CMAKE_INSTALL_SO_NO_EXE)
  set(CMAKE_INSTALL_SO_NO_EXE "1")
endif()

# Is this installation the result of a crosscompile?
if(NOT DEFINED CMAKE_CROSSCOMPILING)
  set(CMAKE_CROSSCOMPILING "FALSE")
endif()

# Set default install directory permissions.
if(NOT DEFINED CMAKE_OBJDUMP)
  set(CMAKE_OBJDUMP "/usr/bin/objdump")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY FILES "/mnt/data/game202/homework2/prt/build/ext_build/openexr/OpenEXR/IlmImf/libIlmImf.a")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/OpenEXR" TYPE FILE FILES
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfForward.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfExport.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfAttribute.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfBoxAttribute.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfCRgbaFile.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfChannelList.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfChannelListAttribute.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfCompressionAttribute.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfDoubleAttribute.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfFloatAttribute.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfFrameBuffer.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfHeader.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfIO.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfInputFile.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfIntAttribute.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfLineOrderAttribute.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfMatrixAttribute.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfOpaqueAttribute.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfOutputFile.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfRgbaFile.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfStringAttribute.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfVecAttribute.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfHuf.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfWav.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfLut.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfArray.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfCompression.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfLineOrder.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfName.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfPixelType.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfVersion.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfXdr.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfConvert.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfPreviewImage.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfPreviewImageAttribute.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfChromaticities.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfChromaticitiesAttribute.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfKeyCode.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfKeyCodeAttribute.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfTimeCode.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfTimeCodeAttribute.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfRational.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfRationalAttribute.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfFramesPerSecond.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfStandardAttributes.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfEnvmap.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfEnvmapAttribute.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfInt64.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfRgba.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfTileDescription.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfTileDescriptionAttribute.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfTiledInputFile.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfTiledOutputFile.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfTiledRgbaFile.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfRgbaYca.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfTestFile.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfThreading.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfB44Compressor.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfStringVectorAttribute.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfMultiView.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfAcesFile.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfMultiPartOutputFile.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfGenericOutputFile.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfMultiPartInputFile.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfGenericInputFile.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfPartType.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfPartHelper.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfOutputPart.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfTiledOutputPart.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfInputPart.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfTiledInputPart.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfDeepScanLineOutputFile.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfDeepScanLineOutputPart.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfDeepScanLineInputFile.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfDeepScanLineInputPart.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfDeepTiledInputFile.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfDeepTiledInputPart.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfDeepTiledOutputFile.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfDeepTiledOutputPart.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfDeepFrameBuffer.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfDeepCompositing.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfCompositeDeepScanLine.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfNamespace.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfMisc.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfDeepImageState.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfDeepImageStateAttribute.h"
    "/mnt/data/game202/homework2/prt/ext/openexr/OpenEXR/IlmImf/ImfFloatVectorAttribute.h"
    )
endif()


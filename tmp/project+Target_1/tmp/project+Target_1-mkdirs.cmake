# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

cmake_minimum_required(VERSION ${CMAKE_VERSION}) # this file comes with cmake

# If CMAKE_DISABLE_SOURCE_CHANGES is set to true and the source directory is an
# existing directory in our source tree, calling file(MAKE_DIRECTORY) on it
# would cause a fatal error, even though it would be a no-op.
if(NOT EXISTS "/home/ibrahim-mohsen/Microprocessors_keil/blackpill_STM32F411CE/tmp/project+Target_1")
  file(MAKE_DIRECTORY "/home/ibrahim-mohsen/Microprocessors_keil/blackpill_STM32F411CE/tmp/project+Target_1")
endif()
file(MAKE_DIRECTORY
  "/home/ibrahim-mohsen/Microprocessors_keil/blackpill_STM32F411CE/tmp/1"
  "/home/ibrahim-mohsen/Microprocessors_keil/blackpill_STM32F411CE/tmp/project+Target_1"
  "/home/ibrahim-mohsen/Microprocessors_keil/blackpill_STM32F411CE/tmp/project+Target_1/tmp"
  "/home/ibrahim-mohsen/Microprocessors_keil/blackpill_STM32F411CE/tmp/project+Target_1/src/project+Target_1-stamp"
  "/home/ibrahim-mohsen/Microprocessors_keil/blackpill_STM32F411CE/tmp/project+Target_1/src"
  "/home/ibrahim-mohsen/Microprocessors_keil/blackpill_STM32F411CE/tmp/project+Target_1/src/project+Target_1-stamp"
)

set(configSubDirs )
foreach(subDir IN LISTS configSubDirs)
    file(MAKE_DIRECTORY "/home/ibrahim-mohsen/Microprocessors_keil/blackpill_STM32F411CE/tmp/project+Target_1/src/project+Target_1-stamp/${subDir}")
endforeach()
if(cfgdir)
  file(MAKE_DIRECTORY "/home/ibrahim-mohsen/Microprocessors_keil/blackpill_STM32F411CE/tmp/project+Target_1/src/project+Target_1-stamp${cfgdir}") # cfgdir has leading slash
endif()

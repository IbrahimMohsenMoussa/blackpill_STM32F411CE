# groups.cmake

# group src
add_library(Group_src OBJECT
  "${SOLUTION_ROOT}/src/rcc.asm"
  "${SOLUTION_ROOT}/src/port.asm"
  "${SOLUTION_ROOT}/src/dio.asm"
  "${SOLUTION_ROOT}/src/SysTick.asm"
  "${SOLUTION_ROOT}/src/adc.asm"
  "${SOLUTION_ROOT}/src/keypad.asm"
  "${SOLUTION_ROOT}/src/stepper.asm"
  "${SOLUTION_ROOT}/src/timer.asm"
  "${SOLUTION_ROOT}/src/tof400f_driver.s"
  "${SOLUTION_ROOT}/src/i2c.asm"
  "${SOLUTION_ROOT}/src/rtc_driver.asm"
  "${SOLUTION_ROOT}/src/sh1106_driver.s"
  "${SOLUTION_ROOT}/src/bitmaps.asm"
  "${SOLUTION_ROOT}/src/main.asm"
  "${SOLUTION_ROOT}/src/ui_driver.s"
)
target_include_directories(Group_src PUBLIC
  $<TARGET_PROPERTY:${CONTEXT},INTERFACE_INCLUDE_DIRECTORIES>
)
target_compile_definitions(Group_src PUBLIC
  $<TARGET_PROPERTY:${CONTEXT},INTERFACE_COMPILE_DEFINITIONS>
)
add_library(Group_src_ABSTRACTIONS INTERFACE)
target_link_libraries(Group_src_ABSTRACTIONS INTERFACE
  ${CONTEXT}_ABSTRACTIONS
)
target_compile_options(Group_src PUBLIC
  $<TARGET_PROPERTY:${CONTEXT},INTERFACE_COMPILE_OPTIONS>
)
target_link_libraries(Group_src PUBLIC
  Group_src_ABSTRACTIONS
)
set(COMPILE_DEFINITIONS
  STM32F411xE
  _RTE_
)
cbuild_set_defines(AS_ARM COMPILE_DEFINITIONS)
set_source_files_properties("${SOLUTION_ROOT}/src/rcc.asm" PROPERTIES
  COMPILE_FLAGS "${COMPILE_DEFINITIONS}"
)
set(COMPILE_DEFINITIONS
  STM32F411xE
  _RTE_
)
cbuild_set_defines(AS_ARM COMPILE_DEFINITIONS)
set_source_files_properties("${SOLUTION_ROOT}/src/port.asm" PROPERTIES
  COMPILE_FLAGS "${COMPILE_DEFINITIONS}"
)
set(COMPILE_DEFINITIONS
  STM32F411xE
  _RTE_
)
cbuild_set_defines(AS_ARM COMPILE_DEFINITIONS)
set_source_files_properties("${SOLUTION_ROOT}/src/dio.asm" PROPERTIES
  COMPILE_FLAGS "${COMPILE_DEFINITIONS}"
)
set(COMPILE_DEFINITIONS
  STM32F411xE
  _RTE_
)
cbuild_set_defines(AS_ARM COMPILE_DEFINITIONS)
set_source_files_properties("${SOLUTION_ROOT}/src/SysTick.asm" PROPERTIES
  COMPILE_FLAGS "${COMPILE_DEFINITIONS}"
)
set(COMPILE_DEFINITIONS
  STM32F411xE
  _RTE_
)
cbuild_set_defines(AS_ARM COMPILE_DEFINITIONS)
set_source_files_properties("${SOLUTION_ROOT}/src/adc.asm" PROPERTIES
  COMPILE_FLAGS "${COMPILE_DEFINITIONS}"
)
set(COMPILE_DEFINITIONS
  STM32F411xE
  _RTE_
)
cbuild_set_defines(AS_ARM COMPILE_DEFINITIONS)
set_source_files_properties("${SOLUTION_ROOT}/src/keypad.asm" PROPERTIES
  COMPILE_FLAGS "${COMPILE_DEFINITIONS}"
)
set(COMPILE_DEFINITIONS
  STM32F411xE
  _RTE_
)
cbuild_set_defines(AS_ARM COMPILE_DEFINITIONS)
set_source_files_properties("${SOLUTION_ROOT}/src/stepper.asm" PROPERTIES
  COMPILE_FLAGS "${COMPILE_DEFINITIONS}"
)
set(COMPILE_DEFINITIONS
  STM32F411xE
  _RTE_
)
cbuild_set_defines(AS_ARM COMPILE_DEFINITIONS)
set_source_files_properties("${SOLUTION_ROOT}/src/timer.asm" PROPERTIES
  COMPILE_FLAGS "${COMPILE_DEFINITIONS}"
)
set(COMPILE_DEFINITIONS
  STM32F411xE
  _RTE_
)
cbuild_set_defines(AS_ARM COMPILE_DEFINITIONS)
set_source_files_properties("${SOLUTION_ROOT}/src/tof400f_driver.s" PROPERTIES
  COMPILE_FLAGS "${COMPILE_DEFINITIONS}"
)
set(COMPILE_DEFINITIONS
  STM32F411xE
  _RTE_
)
cbuild_set_defines(AS_ARM COMPILE_DEFINITIONS)
set_source_files_properties("${SOLUTION_ROOT}/src/i2c.asm" PROPERTIES
  COMPILE_FLAGS "${COMPILE_DEFINITIONS}"
)
set(COMPILE_DEFINITIONS
  STM32F411xE
  _RTE_
)
cbuild_set_defines(AS_ARM COMPILE_DEFINITIONS)
set_source_files_properties("${SOLUTION_ROOT}/src/rtc_driver.asm" PROPERTIES
  COMPILE_FLAGS "${COMPILE_DEFINITIONS}"
)
set(COMPILE_DEFINITIONS
  STM32F411xE
  _RTE_
)
cbuild_set_defines(AS_ARM COMPILE_DEFINITIONS)
set_source_files_properties("${SOLUTION_ROOT}/src/sh1106_driver.s" PROPERTIES
  COMPILE_FLAGS "${COMPILE_DEFINITIONS}"
)
set(COMPILE_DEFINITIONS
  STM32F411xE
  _RTE_
)
cbuild_set_defines(AS_ARM COMPILE_DEFINITIONS)
set_source_files_properties("${SOLUTION_ROOT}/src/bitmaps.asm" PROPERTIES
  COMPILE_FLAGS "${COMPILE_DEFINITIONS}"
)
set(COMPILE_DEFINITIONS
  STM32F411xE
  _RTE_
)
cbuild_set_defines(AS_ARM COMPILE_DEFINITIONS)
set_source_files_properties("${SOLUTION_ROOT}/src/main.asm" PROPERTIES
  COMPILE_FLAGS "${COMPILE_DEFINITIONS}"
)
set(COMPILE_DEFINITIONS
  STM32F411xE
  _RTE_
)
cbuild_set_defines(AS_ARM COMPILE_DEFINITIONS)
set_source_files_properties("${SOLUTION_ROOT}/src/ui_driver.s" PROPERTIES
  COMPILE_FLAGS "${COMPILE_DEFINITIONS}"
)

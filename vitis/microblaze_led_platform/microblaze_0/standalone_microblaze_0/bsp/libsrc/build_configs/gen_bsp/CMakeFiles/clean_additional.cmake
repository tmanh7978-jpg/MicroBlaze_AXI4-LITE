# Additional clean files
cmake_minimum_required(VERSION 3.16)

if("${CONFIG}" STREQUAL "" OR "${CONFIG}" STREQUAL "")
  file(REMOVE_RECURSE
  "D:\\project_final_soc\\vitis\\microblaze_led_platform\\microblaze_0\\standalone_microblaze_0\\bsp\\include\\sleep.h"
  "D:\\project_final_soc\\vitis\\microblaze_led_platform\\microblaze_0\\standalone_microblaze_0\\bsp\\include\\xiltimer.h"
  "D:\\project_final_soc\\vitis\\microblaze_led_platform\\microblaze_0\\standalone_microblaze_0\\bsp\\include\\xtimer_config.h"
  "D:\\project_final_soc\\vitis\\microblaze_led_platform\\microblaze_0\\standalone_microblaze_0\\bsp\\lib\\libxiltimer.a"
  )
endif()

file(GLOB MY_SECURITY_TESTS
  "*.c"
)

foreach(f ${MY_SECURITY_TESTS})
  get_filename_component (exe_name ${f} NAME_WE)
  set (exe_name_small "${exe_name}_small")
  set (exe_name_small "${exe_name}_medium")
  set (exe_name_large "${exe_name}_large")
  message(STATUS "Compiling ${f} ${exe_name}")
  add_executable(${exe_name_small} ${f})
  add_executable(${exe_name_medium} ${f})
  add_executable(${exe_name_large} ${f})
  target_compile_options(${exe_name_small}  PRIVATE -Wno-free-nonheap-object -DALLOCATION_SIZE=8)
  target_compile_options(${exe_name_medium} PRIVATE -Wno-free-nonheap-object -DALLOCATION_SIZE=4096)
  target_compile_options(${exe_name_large}  PRIVATE -Wno-free-nonheap-object -DALLOCATION_SIZE=256*1024)
endforeach()

file(GLOB MY_SECURITY_TESTS
  "*.c"
)

foreach(f ${MY_SECURITY_TESTS})
  get_filename_component (exe_name ${f} NAME_WE)
  message(STATUS "Compiling ${f} ${exe_name}")
  add_executable(${exe_name} ${f})
  target_compile_options(${exe_name} PRIVATE -Wno-free-nonheap-object)
endforeach()
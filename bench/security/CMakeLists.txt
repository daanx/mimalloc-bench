file(GLOB MY_SECURITY_TESTS
  "*.c"
)

macro (add_security_test test_name test_file allocation_size)
  add_executable(${test_name} ${test_file})
  target_compile_options(${test_name}  PRIVATE 
    -Wno-free-nonheap-object 
    -fno-inline
    -fno-builtin-inline
    -fno-inline-small-functions 
    -DALLOCATION_SIZE=${allocation_size})
endmacro ()

foreach(f ${MY_SECURITY_TESTS})
  get_filename_component (exe_name ${f} NAME_WE)
  message(STATUS "Compiling ${f} ${exe_name}")
  add_security_test("${exe_name}_small" ${f} 8)
  add_security_test("${exe_name}_medium" ${f} 4096)
  add_security_test("${exe_name}_large" ${f} 256*1024)
endforeach()

file(GLOB MY_SECURITY_TESTS_CPP
  "*.cc"
)
foreach(f ${MY_SECURITY_TESTS_CPP})
  get_filename_component (exe_name ${f} NAME_WE)
  message(STATUS "Compiling ${f} ${exe_name}")
  add_executable(${exe_name} ${f})
  target_compile_options(${exe_name} PRIVATE -std=c++17 -fsized-deallocation -DALLOCATION_SIZE=4096)
endforeach()

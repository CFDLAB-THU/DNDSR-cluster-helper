# Build-only workaround for source f080ba55627d93a7879ac59be172e25156644e76.
# test_LocalChecks.cpp calls getpid() without including its POSIX declaration.
# Pass via CMAKE_PROJECT_TOP_LEVEL_INCLUDES; do not change solver compilation.
cmake_language(DEFER CALL target_compile_options
    dnds_test_object_contracts PRIVATE -include unistd.h)

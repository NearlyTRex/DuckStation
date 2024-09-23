# Renderer options.
option(ENABLE_OPENGL "Build with OpenGL renderer" ON)
option(ENABLE_VULKAN "Build with Vulkan renderer" ON)
option(BUILD_NOGUI_FRONTEND "Build the NoGUI frontend" OFF)
option(BUILD_QT_FRONTEND "Build the Qt frontend" ON)
option(BUILD_REGTEST "Build regression test runner" OFF)
option(BUILD_TESTS "Build unit tests" OFF)

if(LINUX OR BSD)
  option(ENABLE_X11 "Support X11 window system" ON)
  option(ENABLE_WAYLAND "Support Wayland window system" ON)
  option(ALLOW_INSTALL "Allow installation to CMAKE_INSTALL_PREFIX" OFF)
  option(INSTALL_SELF_CONTAINED "Make self-contained install, i.e. everything in one directory" ON)
endif()
if(APPLE)
  option(SKIP_POSTPROCESS_BUNDLE "Disable bundle post-processing, including Qt additions" OFF)
endif()

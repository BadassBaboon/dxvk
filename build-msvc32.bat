@echo off
rem RealityFX build of DXVK: the 32-bit D3D9 module for GTA IV, built with MSVC.
rem Output: out\vulkan.dll (FusionFix and DLSS IV load DXVK's d3d9 under that name).
rem Needs Visual Studio 2022 with C++ and Python with meson and ninja
rem (python -m pip install --user meson ninja); glslangValidator from the Vulkan SDK.
setlocal
for /f "usebackq delims=" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -property installationPath`) do set VSDIR=%%i
if not defined VSDIR (echo Visual Studio not found & exit /b 1)
set PATH=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer;%PATH%
call "%VSDIR%\VC\Auxiliary\Build\vcvars32.bat" >nul || exit /b 1
for /f "usebackq delims=" %%i in (`python -c "import ninja,os;print(os.path.join(os.path.dirname(ninja.__file__),'data','bin'))"`) do set NINJADIR=%%i
set PATH=%NINJADIR%;%VULKAN_SDK%\Bin;%PATH%
set CC=cl
set CXX=cl
cd /d "%~dp0"
if not exist build.32\build.ninja (
  python -m mesonbuild.mesonmain setup build.32 --buildtype=release --backend=ninja -Denable_d3d10=false -Denable_d3d11=false -Denable_dxgi=false -Denable_d3d8=false || exit /b 1
)
ninja -C build.32 || exit /b 1
if not exist out mkdir out
copy /y build.32\src\d3d9\d3d9.dll out\vulkan.dll >nul || exit /b 1
echo Built out\vulkan.dll

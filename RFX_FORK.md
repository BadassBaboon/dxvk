# RealityFX DXVK fork

DXVK with a few changes for RealityFX shader replacement in GTA IV (FusionFix
loads DXVK's D3D9 module as `vulkan.dll`). Everything else is upstream DXVK.

## What this fork changes

| Change | Where | Why |
|---|---|---|
| `dxvk.vendorNeutralShaders` (default on here) | `DxvkDevice::applyVendorNeutralShaderOptions()` in `src/dxvk/dxvk_device.cpp`, called last in `determineShaderOptions()` | Same SPIR-V on every vendor, so one set of replacement shaders fits Nvidia and AMD |
| D3D9 float emulation follows that option | `src/d3d9/d3d9_options.cpp` | The `hasMulz` driver check picks a different emulation per driver |
| Descriptor heaps and descriptor buffers default to off | `src/dxvk/dxvk_options.cpp` | ReShade add-ons need classic descriptor sets |
| Source hash in each D3D9 shader's name: `<key>;d3d9=<md5>` | `D3D9ShaderConverter::convertShader()` in `src/d3d9/d3d9_shader.cpp` | MD5 of the game's original bytecode: identifies a game shader in any DXVK version and on any device |
| `build-msvc32.bat` | repository root | Builds `out\vulkan.dll` (32-bit, MSVC) |

All three options can still be set in `dxvk.conf`.

## Merging a new upstream release

1. Merge the upstream tag into this fork and fix conflicts. The changes above
   are small and in few places; conflicts, if any, are in those functions.
2. Read every change to `DxvkDevice::determineShaderOptions()` since the last
   merge. Any new flag set from a device feature, property, limit or driver
   check is a new vendor difference: decide whether
   `applyVendorNeutralShaderOptions()` must clear or pin it. Lowerings that are
   valid everywhere may stay as they are.
3. Search `src/d3d9` and `src/dxvk/dxvk_shader*.cpp` for new uses of
   `matchesDriver`, `features()` or `properties()` that change generated code
   rather than pipeline state.
4. Check that the converter still receives `options.name` from
   `D3D9ShaderConverter::convertShader()`, so the `;d3d9=` hash still reaches
   the SPIR-V.
5. Build, then dump shaders on one Nvidia and one AMD machine
   (RealityFX `[General] DumpShaders=1`). Shaders both machines drew must be
   byte-identical; if not, diff one pair with `spirv-dis` to find the new
   difference.
6. Port the replacement shaders: pair old and new shaders by their `d3d9=`
   hash, decompile the new ones, and re-apply the RealityFX blocks.

## Verified

DXVK master `e5ffd0fe` + this fork: an RTX 3090 (Nvidia 610.88) and an
RX 6600 (AMD 2.0.353) produced byte-identical SPIR-V for all 2,039 game
shaders both drew. Intel, older Nvidia drivers (before 580) and Mesa drivers
are not verified and take some driver-specific workarounds that change code.

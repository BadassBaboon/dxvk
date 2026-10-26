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
| Vendor-neutral mode also pins the driver workarounds that rewrite code: sin/cos lowering off (Intel), uint-to-float lowering off (Nvidia before 580), FtoI, F32toF16 and constant-array lowering on (off on Mesa) | `applyVendorNeutralShaderOptions()` | Each of these compiled affected shaders differently on Intel, older Nvidia drivers and Mesa (Proton), so replacements of them never matched there. `dxvk.lowerSinCos = True` still forces Intel's lowering |
| Vendor-neutral mode caps the UBO range used for code generation at 64 KiB | `applyVendorNeutralShaderOptions()` | A constant buffer above the range compiles as a storage buffer; Nvidia's 64 KiB is the smallest verified range, so every device decides the same way |
| `dxvk.sortAdaptersByMemory`: within a device type, the GPU with the most dedicated memory comes first | `DxvkInstance::queryAdapters()` in `src/dxvk/dxvk_instance.cpp`, `src/dxvk/dxvk_options.*` | Upstream keeps the Vulkan loader's order, so with two dedicated GPUs (or a second GPU reported as dedicated) D3D9 adapter 0 could be the smaller one |
| GTA IV / EFLC profile adds `dxvk.hideIntegratedGraphics = True` and `dxvk.sortAdaptersByMemory = True` | `src/util/config/config.cpp` | GTA IV renders on adapter 0: never an integrated GPU while a dedicated one exists, and the largest dedicated GPU first |
| `build-msvc32.bat` | repository root | Builds `out\vulkan.dll` (32-bit, MSVC) |

All options can still be set in `dxvk.conf`; `DXVK_FILTER_DEVICE_NAME` (or
`dxvk.deviceFilter`) still picks a GPU by name.

## Upstream fixes taken ahead of a release

Upstream had not released past v3.1.1 when these were taken (2026-10-26); its
master was `3.2-dev`. Only fixes that leave generated shader code untouched
were cherry-picked onto `e5ffd0fe`. None come from the `dxbc-spirv` submodule
(it now holds the D3D9 compiler), and none touch SPIR-V patching
(`dxvk_shader_spirv.cpp`) or the shader key, so every RealityFX hash stays
valid. Left out on purpose: the submission synchronization and present timing
rework, D3D11, D3D8 and native changes, and Reflex.

Taken: `f20f3631` resolve image, `b2c2622c` fullscreen window-handle resets,
`a57923a9` reset validation failure, `098e41a3` SetLOD, `0847af33` allocator
lock, `89b5490f` FlushImage, `8907e060` scratch memory suballocation,
`d7e283b1` mipmap counter memory, `e0fa1bc8` stencil resolve, `d3d57f45` spec
constant dirty mask, `0ae00031` and `b17c9679` meta copies, `ac400e40` and
`14260d1d` clears, `1de51b9d` fence queue order, `7e03c549` CS thread waiters,
`cb253e0c` command buffer splitting, `29dd21b3` memory priority, `8c8937dd`
shader cache instance freed while in use, `a5250d4a` shader cache LUT reset,
`7d248817` fixed-function null texture revert, `89e9eca9` cubemap face
alignment, `d263e090` fewer CS calls in StretchRect.

`3a71f3cc` (switch texture map data to buffers early) is backported by hand to
the fork's map-mode code, which the upstream commit does not apply to. Without
it, locking one subresource could free the memory file that another locked
subresource's pointer still pointed into.

When upstream tags v3.2, merge the tag (these commits then drop out as
duplicates) and follow the checklist below.

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
shaders both drew. Since then vendor-neutral mode also pins the code-changing
workarounds for Intel, Nvidia before 580 and Mesa; dumps from those devices
are still to be compared.

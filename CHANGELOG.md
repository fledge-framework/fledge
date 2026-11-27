# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2026-11-27

### Changes

---

Packages with breaking changes:

 - [`fledge_assets` - `v0.7.1`](#fledge_assets---v071)
 - [`fledge_camera_2d` - `v0.7.1`](#fledge_camera_2d---v071)
 - [`fledge_ecs` - `v0.7.1`](#fledge_ecs---v071)
 - [`fledge_net` - `v0.7.1`](#fledge_net---v071)
 - [`fledge_yarn` - `v0.7.1`](#fledge_yarn---v071)

Packages with other changes:

 - [`fledge_audio` - `v0.7.1`](#fledge_audio---v071)
 - [`fledge_calendar` - `v0.7.1`](#fledge_calendar---v071)
 - [`fledge_debug` - `v0.7.1`](#fledge_debug---v071)
 - [`fledge_ecs_annotations` - `v0.7.1`](#fledge_ecs_annotations---v071)
 - [`fledge_ecs_generator` - `v0.7.1`](#fledge_ecs_generator---v071)
 - [`fledge_input` - `v0.7.1`](#fledge_input---v071)
 - [`fledge_lighting_2d` - `v0.7.1`](#fledge_lighting_2d---v071)
 - [`fledge_net_steam` - `v0.7.1`](#fledge_net_steam---v071)
 - [`fledge_particles` - `v0.7.1`](#fledge_particles---v071)
 - [`fledge_physics` - `v0.7.1`](#fledge_physics---v071)
 - [`fledge_render_2d` - `v0.7.1`](#fledge_render_2d---v071)
 - [`fledge_save` - `v0.7.1`](#fledge_save---v071)
 - [`fledge_tiled` - `v0.7.1`](#fledge_tiled---v071)
 - [`fledge_tween` - `v0.7.1`](#fledge_tween---v071)
 - [`fledge_ui` - `v0.7.1`](#fledge_ui---v071)
 - [`fledge_window` - `v0.7.1`](#fledge_window---v071)

---

#### `fledge_assets` - `v0.7.1`

 - **FIX**(fledge_assets): keep asset load errors observable. ([24588dd9](https://github.com/fledge-framework/fledge/commit/24588dd9df0a33db894496455cad590922a9ee13))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(*): corrections for retina displays. ([969c8b04](https://github.com/fledge-framework/fledge/commit/969c8b0412126a9693d7418bdceaa4d36e25aee7))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))
 - **BREAKING** **FIX**(fledge_assets): synchronous hot reload that actually reloads. ([24b145eb](https://github.com/fledge-framework/fledge/commit/24b145eb398d87492dda6641ae2f11b07206dd31))

#### `fledge_camera_2d` - `v0.7.1`

 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**(fledge_camera_2d): CameraFollow.marker stays quiet until a target appears. ([d1894e64](https://github.com/fledge-framework/fledge/commit/d1894e645754d3a9418e273826b8d14a80e52c2f))
 - **FIX**(fledge_camera_2d): order ActiveCameraViewSystem after transform_propagate. ([42af6b8b](https://github.com/fledge-framework/fledge/commit/42af6b8baf01bcfc3f58d0c37392cc1912d7a4d1))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**(fledge_yarn): support for cinematics. ([1572d821](https://github.com/fledge-framework/fledge/commit/1572d8214899162164a8a5258bed8b713b8e4965))
 - **FEAT**(fledge_audio): upgrade to leverage soloud. ([13964f36](https://github.com/fledge-framework/fledge/commit/13964f36394d8c39981071d5f03d9d8c153ce4c4))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_camera_2d): expose CameraFollowSystem.systemName and ActiveCameraViewSystem.systemName. ([d42ccd1e](https://github.com/fledge-framework/fledge/commit/d42ccd1eb519d38eb71fc91e7787914cada05f75))
 - **FEAT**(fledge_render_2d): pixel-snap the camera canvas offset when pixelPerfect. ([3137dc16](https://github.com/fledge-framework/fledge/commit/3137dc16178b2d2c35eb4aa9d6d08eae13ccdbe9))
 - **FEAT**: camera-aware widget render path. ([6b8ff1b7](https://github.com/fledge-framework/fledge/commit/6b8ff1b7f1eaf6a930a73d7a4c5a0c4e26f12385))
 - **FEAT**(fledge_camera_2d): CameraFollow updates root camera GlobalTransform2D + marker target. ([4794cfc9](https://github.com/fledge-framework/fledge/commit/4794cfc90072f4ba2c1b05ba3881bb69d71ca3db))
 - **FEAT**(fledge_camera_2d): CameraFollowSystem — declare order + honour pixelPerfect. ([e7a77ef0](https://github.com/fledge-framework/fledge/commit/e7a77ef06b9f96d57dce359a2223212b37ea7f2d))
 - **FEAT**(fledge_render_2d): render interpolation between fixed ticks. ([6179b2d5](https://github.com/fledge-framework/fledge/commit/6179b2d5d1392d5719448521f100bbac640b6b7a))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))
 - **BREAKING** **FIX**(fledge_camera_2d): shake as a view offset, working screenToWorld, bounds at 1:1. ([cad20663](https://github.com/fledge-framework/fledge/commit/cad206632ad52d1fc5c57048269addfcafaea450))

#### `fledge_ecs` - `v0.7.1`

 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**(fledge_ecs): let SyncSystem inherit System defaults. ([e03de26c](https://github.com/fledge-framework/fledge/commit/e03de26ca162caee7277313a66612c1f7012a850))
 - **FIX**(fledge_ecs): keep the hierarchy consistent on despawn. ([13137a3e](https://github.com/fledge-framework/fledge/commit/13137a3eb9a0cb2e0c1f21b5ec7543ebcf35dd11))
 - **FIX**(fledge_ecs): honour change baselines in queryMut and set run conditions. ([f91c167b](https://github.com/fledge-framework/fledge/commit/f91c167be487abfd7a955b50e42d10ec36d8ccaa))
 - **FIX**(fledge_ecs): fire observers on despawn and bulk spawn. ([dcfbccb6](https://github.com/fledge-framework/fledge/commit/dcfbccb6c7ff1ae8880257d805ecbd7a5c4574a5))
 - **FIX**(fledge_ecs): make Added/Changed filters track per-system runs. ([7c9d7801](https://github.com/fledge-framework/fledge/commit/7c9d7801456c10d09c7472e7b6a5674b2aa93547))
 - **FIX**(fledge_ecs): fire OnExitState when leaving the state. ([cd5b4a58](https://github.com/fledge-framework/fledge/commit/cd5b4a58bfbda0098d8da319be1b3d904ffb295a))
 - **FIX**(fledge_input): fix timing issue for action resolution. ([62356b0d](https://github.com/fledge-framework/fledge/commit/62356b0d81db96018025579a544517bf85499de5))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FIX**(fledge_ecs): create missing getters. ([e8f8ee3b](https://github.com/fledge-framework/fledge/commit/e8f8ee3ba27bf40d69599dda78ed27353f0cd7bb))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_ecs): explicit before/after overrides registration-order conflict edges. ([e698e92f](https://github.com/fledge-framework/fledge/commit/e698e92fd4bf396d60d5131f94ea3a0296b9f25e))
 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_ecs): fan-out before/after when multiple systems share a name. ([664c4fd9](https://github.com/fledge-framework/fledge/commit/664c4fd9f8990ae17e2e1a3062c30a832ab24b9a))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**(fledge_ecs): add FixedTimestep.nudge for external clock sync. ([25e3cfe5](https://github.com/fledge-framework/fledge/commit/25e3cfe5b96a300e522013c9d58a1a2903305f8b))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**(*): corrections for retina displays. ([969c8b04](https://github.com/fledge-framework/fledge/commit/969c8b0412126a9693d7418bdceaa4d36e25aee7))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_save): create fledge_save package. ([48a3a327](https://github.com/fledge-framework/fledge/commit/48a3a327b9c0950ec320d7f805cce19bf7a300f6))
 - **FEAT**(fledge_ecs): add game checkpoint api. ([3b140dcc](https://github.com/fledge-framework/fledge/commit/3b140dccd5e52f9e6159e2059c161914cbafb6f7))
 - **FEAT**(fledge_physics): extract collision engine into new package. ([cc31acc0](https://github.com/fledge-framework/fledge/commit/cc31acc0a02159fd39fa0dcdb9655d223c4c0027))
 - **FEAT**(fledge_tiled): refactor TilemapSpawnConfig API. ([35b12d1e](https://github.com/fledge-framework/fledge/commit/35b12d1eaa72f7e703f6820b4e0f8d69452f509e))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**(fledge_tiled): extract collision from tilesets. ([a5db2352](https://github.com/fledge-framework/fledge/commit/a5db2352f66ec5d5f1d61a8541dbda9b3ff9b1a2))
 - **FEAT**(fledge_ecs): handle machine idle time. ([a460f88a](https://github.com/fledge-framework/fledge/commit/a460f88a931e1af0941b906d5e0e464bf3cbbff5))
 - **FEAT**(fledge_ecs): add advanced disposal functions. ([79479d10](https://github.com/fledge-framework/fledge/commit/79479d1027eb91954975c140c390f208a4f7de84))
 - **FEAT**(examples): add new drifter game demo. ([c126a144](https://github.com/fledge-framework/fledge/commit/c126a144fe20402104b01a259d4ee36a00327d92))
 - **DOCS**(fledge_ecs): schedule_label comments reflect that App.tick drives fixed/extract/render. ([82292987](https://github.com/fledge-framework/fledge/commit/82292987556e9f327048a00c1a418c7f506b5b62))
 - **BREAKING** **FIX**(fledge_ecs): plugin lifecycle, App.dispose, run() yielding, strict single(). ([8251f76f](https://github.com/fledge-framework/fledge/commit/8251f76fc82597dc028287760b611cd2081443d0))

#### `fledge_net` - `v0.7.1`

 - **FIX**(fledge_net): close on host disconnect, allow full-host rejoins, resolve through encryption. ([4f873975](https://github.com/fledge-framework/fledge/commit/4f8739752c32f82c767abc83bb678a8474b36fb7))
 - **FIX**(fledge_net): smooth client interpolation with a decoupled render clock. ([b575aa35](https://github.com/fledge-framework/fledge/commit/b575aa35a49cb1da6f8154254c4bbd0c707c00d2))
 - **FIX**(fledge_net): latency fixes. ([c686b6ec](https://github.com/fledge-framework/fledge/commit/c686b6ec4727b4923f2e5a851718fb276bd1372c))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(*): corrections for retina displays. ([969c8b04](https://github.com/fledge-framework/fledge/commit/969c8b0412126a9693d7418bdceaa4d36e25aee7))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**(fledge_yarn): support for cinematics. ([1572d821](https://github.com/fledge-framework/fledge/commit/1572d8214899162164a8a5258bed8b713b8e4965))
 - **FEAT**(fledge_physics): weighted pathfinding and cost-aware path smoothing. ([42a8899d](https://github.com/fledge-framework/fledge/commit/42a8899d19b666779323c756e6e520b4c1d5e2c3))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**(fledge_ecs): add FixedTimestep.nudge for external clock sync. ([25e3cfe5](https://github.com/fledge-framework/fledge/commit/25e3cfe5b96a300e522013c9d58a1a2903305f8b))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_net): remediate documented limitations. ([203a78a6](https://github.com/fledge-framework/fledge/commit/203a78a6093897de435f9cf4528e3afcfab6073f))
 - **FEAT**(fledge_net): create net package. ([dfed40d6](https://github.com/fledge-framework/fledge/commit/dfed40d6773ee9371bca5cf432372e265bdc0bb0))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))
 - **BREAKING** **FIX**(fledge_net): hidden ancestors hide their descendants. ([db1a84d0](https://github.com/fledge-framework/fledge/commit/db1a84d05390675c2795d707780934ec8b01f6db))

#### `fledge_yarn` - `v0.7.1`

 - **FIX**(fledge_yarn): log malformed conditions. ([a3ffb06b](https://github.com/fledge-framework/fledge/commit/a3ffb06bff6c1d5f14d0376b2f107c549c9a2b70))
 - **FIX**(fledge_yarn): jump to a missing node no longer leaves the previous line up. ([33a6ac05](https://github.com/fledge-framework/fledge/commit/33a6ac054cab948839ec306e8a3363dd107e566d))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(*): corrections for retina displays. ([969c8b04](https://github.com/fledge-framework/fledge/commit/969c8b0412126a9693d7418bdceaa4d36e25aee7))
 - **FEAT**(fledge_render_2d): improve culling. ([966e8657](https://github.com/fledge-framework/fledge/commit/966e86576f4f886ad4afcd24958e607188e222f6))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**(fledge_yarn): support for cinematics. ([1572d821](https://github.com/fledge-framework/fledge/commit/1572d8214899162164a8a5258bed8b713b8e4965))
 - **FEAT**(fledge_audio): upgrade to leverage soloud. ([13964f36](https://github.com/fledge-framework/fledge/commit/13964f36394d8c39981071d5f03d9d8c153ce4c4))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_yarn): pausing command callbacks. ([8c117ce1](https://github.com/fledge-framework/fledge/commit/8c117ce153f3908816d22c3240c98e75b5a3af2d))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_yarn): create fledge_yarn for yarnspinner. ([9bbee221](https://github.com/fledge-framework/fledge/commit/9bbee2213966a290074b265ed60e57198d1047c0))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))
 - **DOCS**(fledge_yarn): tag grammar. ([6a4895fb](https://github.com/fledge-framework/fledge/commit/6a4895fbe48578d06d35c1afe446ba93f0411966))
 - **BREAKING** **FIX**(fledge_yarn): keep quoted strings, end once, hold on pausing commands. ([3cd78442](https://github.com/fledge-framework/fledge/commit/3cd78442c0a76f41522d0562092d003ea514a020))
 - **BREAKING** **FEAT**(fledge_yarn): event-driven dialogue layer. ([3f4be34d](https://github.com/fledge-framework/fledge/commit/3f4be34d8104c2cc2a56030dfe7012421304900b))

#### `fledge_audio` - `v0.7.1`

 - **FIX**(fledge_audio): mix spatial audio in world space and report source endings. ([f78de16f](https://github.com/fledge-framework/fledge/commit/f78de16f9d9a2b5ba3f36e7b6a1d808c5fd5ccf0))
 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**: bump lower bound of fledge_audio. ([1198dd84](https://github.com/fledge-framework/fledge/commit/1198dd8466d6d92b11ebc5b9127e6ce66c92edab))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**(fledge_tiled): extract collision from tilesets. ([a5db2352](https://github.com/fledge-framework/fledge/commit/a5db2352f66ec5d5f1d61a8541dbda9b3ff9b1a2))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**(fledge_audio): upgrade to leverage soloud. ([13964f36](https://github.com/fledge-framework/fledge/commit/13964f36394d8c39981071d5f03d9d8c153ce4c4))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_audio): expose systemName on AudioInitSystem and SpatialAudioSystem. ([d79dce3c](https://github.com/fledge-framework/fledge/commit/d79dce3c6c224120e5cf6b7b79454a681d6b5f14))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_tiled): refactor TilemapSpawnConfig API. ([35b12d1e](https://github.com/fledge-framework/fledge/commit/35b12d1eaa72f7e703f6820b4e0f8d69452f509e))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))

#### `fledge_calendar` - `v0.7.1`

 - **FIX**(fledge_calendar): fail loudly without WallTime, format non-24h days. ([09e613f6](https://github.com/fledge-framework/fledge/commit/09e613f6c92b56e8fb4fec470419f4114e31a592))
 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**(fledge_calendar): order CalendarSystem after wallTimeUpdate. ([f61ce1e6](https://github.com/fledge-framework/fledge/commit/f61ce1e69778a51f5f4ea3befe0e4b99076ee763))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(*): corrections for retina displays. ([969c8b04](https://github.com/fledge-framework/fledge/commit/969c8b0412126a9693d7418bdceaa4d36e25aee7))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: adopt CalendarPlugin. ([815b8576](https://github.com/fledge-framework/fledge/commit/815b8576d960004c378f99d379a4d0949dbdf8ef))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))

#### `fledge_debug` - `v0.7.1`

 - **FIX**(fledge_debug): draw the frustum the widget actually shows. ([23ca8a2d](https://github.com/fledge-framework/fledge/commit/23ca8a2d3acfda7669bcd4885feef90a09801c7b))
 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**(fledge_debug): keep an existing DebugConfig instead of overwriting it. ([8c5b3725](https://github.com/fledge-framework/fledge/commit/8c5b3725bbfd84a86f4f0d87d6a77840ab12f242))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(*): corrections for retina displays. ([969c8b04](https://github.com/fledge-framework/fledge/commit/969c8b0412126a9693d7418bdceaa4d36e25aee7))
 - **FEAT**(fledge_render_2d): improve culling. ([966e8657](https://github.com/fledge-framework/fledge/commit/966e86576f4f886ad4afcd24958e607188e222f6))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_debug): auto-refresh ScheduleOrderingReport on first tick. ([0e152b9e](https://github.com/fledge-framework/fledge/commit/0e152b9e6eaf00f9f30096d9f61c1f2c7a0c777a))
 - **FEAT**(fledge_debug): optional overlay and a standalone stats plugin. ([aef458b1](https://github.com/fledge-framework/fledge/commit/aef458b1ff7ceb251fbb46c7d9fbe244f43939f0))
 - **FEAT**: camera-aware widget render path. ([6b8ff1b7](https://github.com/fledge-framework/fledge/commit/6b8ff1b7f1eaf6a930a73d7a4c5a0c4e26f12385))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))

#### `fledge_ecs_annotations` - `v0.7.1`

 - **FIX**(fledge_ecs): fire observers on despawn and bulk spawn. ([dcfbccb6](https://github.com/fledge-framework/fledge/commit/dcfbccb6c7ff1ae8880257d805ecbd7a5c4574a5))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))

#### `fledge_ecs_generator` - `v0.7.1`

 - **FIX**(fledge_ecs_generator): apply Commands and await async systems. ([4c168c54](https://github.com/fledge-framework/fledge/commit/4c168c543a6c0d094f0530cc556dab2080df5610))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): create net package. ([dfed40d6](https://github.com/fledge-framework/fledge/commit/dfed40d6773ee9371bca5cf432372e265bdc0bb0))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))
 - **DOCS**(fledge_ecs_generator): match the generator doc comment to real output. ([5f1285ee](https://github.com/fledge-framework/fledge/commit/5f1285eef9a0ced03c6e1e7f0f29eee3a7fda135))

#### `fledge_input` - `v0.7.1`

 - **FIX**(fledge_input): release every mouse button, restore contexts, honour priority. ([176a8df3](https://github.com/fledge-framework/fledge/commit/176a8df36b5d0402356754c1b5b7521450909ff7))
 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FIX**(fledge_input): persist input transition flags through the entire frame. ([f96f8ca2](https://github.com/fledge-framework/fledge/commit/f96f8ca2e5ae6f5cbf502d422014321d93ce4a1a))
 - **FIX**(fledge_input): fix timing issue for action resolution. ([62356b0d](https://github.com/fledge-framework/fledge/commit/62356b0d81db96018025579a544517bf85499de5))
 - **FEAT**(fledge_input): extend focus bridge. ([d70ab856](https://github.com/fledge-framework/fledge/commit/d70ab856af51a16f187da4c1bd7bf619e0c92f08))
 - **FEAT**(fledge_render_2d): improve culling. ([966e8657](https://github.com/fledge-framework/fledge/commit/966e86576f4f886ad4afcd24958e607188e222f6))
 - **FEAT**(fledge_tiled): extract collision from tilesets. ([a5db2352](https://github.com/fledge-framework/fledge/commit/a5db2352f66ec5d5f1d61a8541dbda9b3ff9b1a2))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**(fledge_audio): upgrade to leverage soloud. ([13964f36](https://github.com/fledge-framework/fledge/commit/13964f36394d8c39981071d5f03d9d8c153ce4c4))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(examples): add new drifter game demo. ([c126a144](https://github.com/fledge-framework/fledge/commit/c126a144fe20402104b01a259d4ee36a00327d92))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_net): create net package. ([dfed40d6](https://github.com/fledge-framework/fledge/commit/dfed40d6773ee9371bca5cf432372e265bdc0bb0))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))

#### `fledge_lighting_2d` - `v0.7.1`

 - **FIX**(fledge_lighting_2d): camera-aware additive light pass fills the visible world viewport. ([23bae1ac](https://github.com/fledge-framework/fledge/commit/23bae1acc5358817a3a469ee8000f379e21e46bf))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(*): corrections for retina displays. ([969c8b04](https://github.com/fledge-framework/fledge/commit/969c8b0412126a9693d7418bdceaa4d36e25aee7))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**(fledge_audio): upgrade to leverage soloud. ([13964f36](https://github.com/fledge-framework/fledge/commit/13964f36394d8c39981071d5f03d9d8c153ce4c4))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_lighting_2d): optional AmbientLight.bounds clips the overSprites multiply. ([e6429852](https://github.com/fledge-framework/fledge/commit/e64298524b34d0fcdcb755570f262c67727e75c1))
 - **FEAT**: camera-aware widget render path. ([6b8ff1b7](https://github.com/fledge-framework/fledge/commit/6b8ff1b7f1eaf6a930a73d7a4c5a0c4e26f12385))
 - **FEAT**(fledge_lighting_2d): AmbientBlend.overSprites — ambient darkens sprites too. ([7d0c33db](https://github.com/fledge-framework/fledge/commit/7d0c33dbb8bb5bb6a89b4d73faecfa04d2780a07))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))
 - **DOCS**(*): fix stale comments in fledge_lighting_2d and drifter. ([80c17633](https://github.com/fledge-framework/fledge/commit/80c176333b2d34f78dfb6a4239c154b9f8030e55))

#### `fledge_net_steam` - `v0.7.1`

 - **FIX**(fledge_net_steam): bound session requests and leave the lobby on join errors. ([df2d3e2b](https://github.com/fledge-framework/fledge/commit/df2d3e2bade8ec408b32fad8dbfa9532d9cbfe29))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))

#### `fledge_particles` - `v0.7.1`

 - **FIX**(fledge_particles): register the extractor whatever the plugin order. ([310c5c29](https://github.com/fledge-framework/fledge/commit/310c5c29dbd70659d1b0434c51f9308d444d825b))
 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_particles): cull particles outside the camera view. ([435f3937](https://github.com/fledge-framework/fledge/commit/435f3937b8ec37d7a1af92e5366491235085bb57))
 - **FEAT**(fledge_render_2d): improve culling. ([966e8657](https://github.com/fledge-framework/fledge/commit/966e86576f4f886ad4afcd24958e607188e222f6))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))

#### `fledge_physics` - `v0.7.1`

 - **FIX**(fledge_physics): tight rotated bounds, cheap hasPath, fixed-mode sets. ([1049b723](https://github.com/fledge-framework/fledge/commit/1049b7238f6e01f1cb767ed812582bc561d354ab))
 - **FIX**(fledge_physics): yieldAfter counts blocked contact, not only overlap. ([f6bbb220](https://github.com/fledge-framework/fledge/commit/f6bbb220509bead9664c04cc4dd97051f0290eda))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_physics): add flutter dependency to package. ([c6608ee5](https://github.com/fledge-framework/fledge/commit/c6608ee5128672c4ec03963ca3b4abd8c507673f))
 - **FEAT**(*): corrections for retina displays. ([969c8b04](https://github.com/fledge-framework/fledge/commit/969c8b0412126a9693d7418bdceaa4d36e25aee7))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**(fledge_physics): prevent clipping during pathfinding. ([dac8ffaf](https://github.com/fledge-framework/fledge/commit/dac8ffaf3c8dd2815a626ae80694561823530a08))
 - **FEAT**(fledge_physics): weighted pathfinding and cost-aware path smoothing. ([42a8899d](https://github.com/fledge-framework/fledge/commit/42a8899d19b666779323c756e6e520b4c1d5e2c3))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**(fledge_physics): expose systemName on collision + velocity systems. ([4b0e8a58](https://github.com/fledge-framework/fledge/commit/4b0e8a58c63ef1cc974419c777e23d5a8fefa1e4))
 - **FEAT**(fledge_physics): yieldAfter — pass-through after sustained contact. ([5af431e0](https://github.com/fledge-framework/fledge/commit/5af431e06101b6f80350c8e23416c58eedc202bb))
 - **FEAT**(fledge_physics): opt-in dynamic-vs-dynamic blocking. ([e264f586](https://github.com/fledge-framework/fledge/commit/e264f586778836cd99b64aafdbdadb056455885f))
 - **FEAT**(fledge_physics): fixed-step integration + resolution. ([271b41de](https://github.com/fledge-framework/fledge/commit/271b41defa06e8e9f58218e39fed4c6ab3989720))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(examples): add new drifter game demo. ([c126a144](https://github.com/fledge-framework/fledge/commit/c126a144fe20402104b01a259d4ee36a00327d92))
 - **FEAT**(fledge_physics): extract collision engine into new package. ([cc31acc0](https://github.com/fledge-framework/fledge/commit/cc31acc0a02159fd39fa0dcdb9655d223c4c0027))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))

#### `fledge_render_2d` - `v0.7.1`

 - **REFACTOR**(fledge_render): combine core systems from fledge_render_flutter. ([4126c272](https://github.com/fledge-framework/fledge/commit/4126c272f2ddd3a198a285c5a80afdbea79aa126))
 - **FIX**(fledge_render_2d): make GlobalTransform2D.inverse return the inverse. ([61a4e8a4](https://github.com/fledge-framework/fledge/commit/61a4e8a4cd348c3f371d1fffbc4a4a019f17fbf0))
 - **FIX**(fledge_render_2d): canvas drawer supports mirrored sprites. ([fc2b3440](https://github.com/fledge-framework/fledge/commit/fc2b34408cf39ea7ff0420a6b7100ff9ba41cad0))
 - **FIX**(fledge_render_2d): Y-sort keeps working past y = 100 px. ([faa9fd04](https://github.com/fledge-framework/fledge/commit/faa9fd04fab36f3a2b61b74155d9223eaba802ce))
 - **FIX**(fledge_render_2d): sprite anchor formula no longer mirrored. ([dcd70d65](https://github.com/fledge-framework/fledge/commit/dcd70d65a88a2cc51aaf9a4b95e0fecfb15ff91f))
 - **FIX**(fledge_render_2d): atlas/tile frames no longer draw offset by source position. ([c786f3b2](https://github.com/fledge-framework/fledge/commit/c786f3b28483f558c18078eb4417eff40a00850e))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**(*): corrections for retina displays. ([969c8b04](https://github.com/fledge-framework/fledge/commit/969c8b0412126a9693d7418bdceaa4d36e25aee7))
 - **FEAT**(fledge_render_2d): cull atlas sprites like plain sprites. ([2b1bb4df](https://github.com/fledge-framework/fledge/commit/2b1bb4dfd8a1e691424fd1ded780953485f9551a))
 - **FEAT**(fledge_render_2d): improve culling. ([966e8657](https://github.com/fledge-framework/fledge/commit/966e86576f4f886ad4afcd24958e607188e222f6))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**(fledge_physics): prevent clipping during pathfinding. ([dac8ffaf](https://github.com/fledge-framework/fledge/commit/dac8ffaf3c8dd2815a626ae80694561823530a08))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_render_2d): expose systemName on transform / animation / transition systems. ([5813ff7a](https://github.com/fledge-framework/fledge/commit/5813ff7a34bba1623b5abdec394d8bcfa304e6d6))
 - **FEAT**(fledge_render_2d): pixel-snap the camera canvas offset when pixelPerfect. ([3137dc16](https://github.com/fledge-framework/fledge/commit/3137dc16178b2d2c35eb4aa9d6d08eae13ccdbe9))
 - **FEAT**: camera-aware widget render path. ([6b8ff1b7](https://github.com/fledge-framework/fledge/commit/6b8ff1b7f1eaf6a930a73d7a4c5a0c4e26f12385))
 - **FEAT**(fledge_render_2d): AtlasSprite gains an anchor field. ([d713ff50](https://github.com/fledge-framework/fledge/commit/d713ff5000a9673fc30b363d7833cf5a1a6be499))
 - **FEAT**(fledge_render_2d): render interpolation between fixed ticks. ([6179b2d5](https://github.com/fledge-framework/fledge/commit/6179b2d5d1392d5719448521f100bbac640b6b7a))
 - **FEAT**(fledge_render_2d): emit TransitionCompleted when a fade transition finishes. ([85d3f225](https://github.com/fledge-framework/fledge/commit/85d3f2250be1ff9b952a5ddf50c6db9eaf78a097))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_save): create fledge_save package. ([48a3a327](https://github.com/fledge-framework/fledge/commit/48a3a327b9c0950ec320d7f805cce19bf7a300f6))
 - **FEAT**(fledge_tiled): add CulledTilemapExtractor. ([8ad8e658](https://github.com/fledge-framework/fledge/commit/8ad8e65817ad8074f55929085fe6d8747da6e114))
 - **FEAT**(fledge_tiled): refactor TilemapSpawnConfig API. ([35b12d1e](https://github.com/fledge-framework/fledge/commit/35b12d1eaa72f7e703f6820b4e0f8d69452f509e))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))

#### `fledge_save` - `v0.7.1`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(*): corrections for retina displays. ([969c8b04](https://github.com/fledge-framework/fledge/commit/969c8b0412126a9693d7418bdceaa4d36e25aee7))
 - **FEAT**(fledge_audio): upgrade to leverage soloud. ([13964f36](https://github.com/fledge-framework/fledge/commit/13964f36394d8c39981071d5f03d9d8c153ce4c4))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: adopt CalendarPlugin. ([815b8576](https://github.com/fledge-framework/fledge/commit/815b8576d960004c378f99d379a4d0949dbdf8ef))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_save): create fledge_save package. ([48a3a327](https://github.com/fledge-framework/fledge/commit/48a3a327b9c0950ec320d7f805cce19bf7a300f6))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))
 - **DOCS**(fledge_save): fix stale SaveManager and library examples. ([408ae731](https://github.com/fledge-framework/fledge/commit/408ae7313dc2cf4ef464916e5c0a50e893bc6e0d))

#### `fledge_tiled` - `v0.7.1`

 - **REFACTOR**(fledge_tiled): depend on fledge_render_2d instead of the fledge_render shim. ([72becfe6](https://github.com/fledge-framework/fledge/commit/72becfe6bef448a30cf5a4d59bbd6fed651678a9))
 - **REFACTOR**(fledge_render): combine core systems from fledge_render_flutter. ([4126c272](https://github.com/fledge-framework/fledge/commit/4126c272f2ddd3a198a285c5a80afdbea79aa126))
 - **FIX**(fledge_tiled): parallax like Tiled, image-collection tiles, tile offsets. ([1efa710e](https://github.com/fledge-framework/fledge/commit/1efa710ebc5e0744149bc10df2e9c5dbd763739b))
 - **FIX**(fledge_tiled): render infinite maps, size oversized tiles, implement TsxLoader. ([bae96543](https://github.com/fledge-framework/fledge/commit/bae965435950188f7058d80c04afc89420f3c894))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**(*): corrections for retina displays. ([969c8b04](https://github.com/fledge-framework/fledge/commit/969c8b0412126a9693d7418bdceaa4d36e25aee7))
 - **FEAT**(fledge_render_2d): improve culling. ([966e8657](https://github.com/fledge-framework/fledge/commit/966e86576f4f886ad4afcd24958e607188e222f6))
 - **FEAT**(fledge_tiled): extract collision from tilesets. ([a5db2352](https://github.com/fledge-framework/fledge/commit/a5db2352f66ec5d5f1d61a8541dbda9b3ff9b1a2))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**(fledge_physics): weighted pathfinding and cost-aware path smoothing. ([42a8899d](https://github.com/fledge-framework/fledge/commit/42a8899d19b666779323c756e6e520b4c1d5e2c3))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_tiled): expose TilemapSpawnSystem.systemName. ([3b5ea9f9](https://github.com/fledge-framework/fledge/commit/3b5ea9f9c3e4adaf9f2694133b83b188a3b73aa1))
 - **FEAT**(fledge_tiled): emit ExtractedSprite so tiles draw through FledgeRenderView. ([76ad87f7](https://github.com/fledge-framework/fledge/commit/76ad87f7c9f3b5a8d1bb64bc9847931924227b44))
 - **FEAT**(fledge_tiled): read tilemaps from Assets<TilemapAsset>. ([eb0515f2](https://github.com/fledge-framework/fledge/commit/eb0515f27f746f536a4060683b178716b9d40b3c))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_tiled): add CulledTilemapExtractor. ([8ad8e658](https://github.com/fledge-framework/fledge/commit/8ad8e65817ad8074f55929085fe6d8747da6e114))
 - **FEAT**(fledge_tiled): add support for pathfinding. ([23ba2e0c](https://github.com/fledge-framework/fledge/commit/23ba2e0cad68aabb2bc8a7a0fab52c0af96acd58))
 - **FEAT**(fledge_tiled): enable class based tile sorting. ([291d9a12](https://github.com/fledge-framework/fledge/commit/291d9a12ed5d99912919497b024e7fdd286ae1ce))
 - **FEAT**(fledge_tiled): refactor TilemapSpawnConfig API. ([35b12d1e](https://github.com/fledge-framework/fledge/commit/35b12d1eaa72f7e703f6820b4e0f8d69452f509e))
 - **FEAT**(fledge_render): use layer enums rather than magic numbers. ([b7337885](https://github.com/fledge-framework/fledge/commit/b73378851a5fc04ea34893e6cd1690a6067b3a46))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))

#### `fledge_tween` - `v0.7.1`

 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))

#### `fledge_ui` - `v0.7.1`

 - **FIX**(fledge_ui): apply UiImage tint colours, add overlay repaint. ([b3f2d33d](https://github.com/fledge-framework/fledge/commit/b3f2d33d123b641d18850206c4827447c77126f3))
 - **FIX**(fledge_ui): make FledgeUiOverlay draw extracted elements. ([1ed52f1d](https://github.com/fledge-framework/fledge/commit/1ed52f1d8a2774eab71fd8d5951a5ed53d5d352b))
 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_ui): placement mode. ([7a378aef](https://github.com/fledge-framework/fledge/commit/7a378aeff4540bfc9b78f4755875ac02fbd153d0))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))

#### `fledge_window` - `v0.7.1`

 - **FIX**(fledge_window): report real display refresh rates. ([404e7d4c](https://github.com/fledge-framework/fledge/commit/404e7d4c61537b5d68394efc1907d2b3531f6b78))
 - **FIX**(fledge_window): stop awaiting window_manager every frame. ([2266e92f](https://github.com/fledge-framework/fledge/commit/2266e92f82f20df492fe708f7d94c726d8ba654c))
 - **FIX**(fledge_window): report OS focus, resize and move changes. ([0378ca85](https://github.com/fledge-framework/fledge/commit/0378ca8539f156dfc6f017d00459e02eb3ee4fcb))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**(*): corrections for retina displays. ([969c8b04](https://github.com/fledge-framework/fledge/commit/969c8b0412126a9693d7418bdceaa4d36e25aee7))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_window): expose WindowInitSystem.systemName. ([1c1bd0c7](https://github.com/fledge-framework/fledge/commit/1c1bd0c71295a6208389ac2d45994978507755cb))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(examples): add new drifter game demo. ([c126a144](https://github.com/fledge-framework/fledge/commit/c126a144fe20402104b01a259d4ee36a00327d92))
 - **FEAT**(fledge_window): add error handling. ([affec7da](https://github.com/fledge-framework/fledge/commit/affec7dacc8dd5821d09adc6e96ebc2258a64f5f))
 - **FEAT**(fledge_net): create net package. ([dfed40d6](https://github.com/fledge-framework/fledge/commit/dfed40d6773ee9371bca5cf432372e265bdc0bb0))
 - **FEAT**(fledge_window): add close command on app. ([d30f616f](https://github.com/fledge-framework/fledge/commit/d30f616feda5b50af3217ea505815ceb8c360705))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))


## 2026-11-25

### Changes

---

Packages with breaking changes:

 - [`fledge_assets` - `v0.7.0`](#fledge_assets---v070)
 - [`fledge_camera_2d` - `v0.7.0`](#fledge_camera_2d---v070)
 - [`fledge_ecs` - `v0.7.0`](#fledge_ecs---v070)
 - [`fledge_net` - `v0.7.0`](#fledge_net---v070)
 - [`fledge_yarn` - `v0.7.0`](#fledge_yarn---v070)

Packages with other changes:

 - [`fledge_audio` - `v0.7.0`](#fledge_audio---v070)
 - [`fledge_calendar` - `v0.7.0`](#fledge_calendar---v070)
 - [`fledge_debug` - `v0.7.0`](#fledge_debug---v070)
 - [`fledge_ecs_annotations` - `v0.7.0`](#fledge_ecs_annotations---v070)
 - [`fledge_ecs_generator` - `v0.7.0`](#fledge_ecs_generator---v070)
 - [`fledge_input` - `v0.7.0`](#fledge_input---v070)
 - [`fledge_lighting_2d` - `v0.7.0`](#fledge_lighting_2d---v070)
 - [`fledge_net_steam` - `v0.7.0`](#fledge_net_steam---v070)
 - [`fledge_particles` - `v0.7.0`](#fledge_particles---v070)
 - [`fledge_physics` - `v0.7.0`](#fledge_physics---v070)
 - [`fledge_render_2d` - `v0.7.0`](#fledge_render_2d---v070)
 - [`fledge_save` - `v0.7.0`](#fledge_save---v070)
 - [`fledge_tiled` - `v0.7.0`](#fledge_tiled---v070)
 - [`fledge_tween` - `v0.7.0`](#fledge_tween---v070)
 - [`fledge_ui` - `v0.7.0`](#fledge_ui---v070)
 - [`fledge_window` - `v0.7.0`](#fledge_window---v070)

---

#### `fledge_assets` - `v0.7.0`

 - **FIX**(fledge_assets): keep asset load errors observable. ([24588dd9](https://github.com/fledge-framework/fledge/commit/24588dd9df0a33db894496455cad590922a9ee13))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))
 - **BREAKING** **FIX**(fledge_assets): synchronous hot reload that actually reloads. ([24b145eb](https://github.com/fledge-framework/fledge/commit/24b145eb398d87492dda6641ae2f11b07206dd31))

#### `fledge_camera_2d` - `v0.7.0`

 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**(fledge_camera_2d): CameraFollow.marker stays quiet until a target appears. ([d1894e64](https://github.com/fledge-framework/fledge/commit/d1894e645754d3a9418e273826b8d14a80e52c2f))
 - **FIX**(fledge_camera_2d): order ActiveCameraViewSystem after transform_propagate. ([42af6b8b](https://github.com/fledge-framework/fledge/commit/42af6b8baf01bcfc3f58d0c37392cc1912d7a4d1))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**(fledge_yarn): support for cinematics. ([1572d821](https://github.com/fledge-framework/fledge/commit/1572d8214899162164a8a5258bed8b713b8e4965))
 - **FEAT**(fledge_audio): upgrade to leverage soloud. ([13964f36](https://github.com/fledge-framework/fledge/commit/13964f36394d8c39981071d5f03d9d8c153ce4c4))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_camera_2d): expose CameraFollowSystem.systemName and ActiveCameraViewSystem.systemName. ([d42ccd1e](https://github.com/fledge-framework/fledge/commit/d42ccd1eb519d38eb71fc91e7787914cada05f75))
 - **FEAT**(fledge_render_2d): pixel-snap the camera canvas offset when pixelPerfect. ([3137dc16](https://github.com/fledge-framework/fledge/commit/3137dc16178b2d2c35eb4aa9d6d08eae13ccdbe9))
 - **FEAT**: camera-aware widget render path. ([6b8ff1b7](https://github.com/fledge-framework/fledge/commit/6b8ff1b7f1eaf6a930a73d7a4c5a0c4e26f12385))
 - **FEAT**(fledge_camera_2d): CameraFollow updates root camera GlobalTransform2D + marker target. ([4794cfc9](https://github.com/fledge-framework/fledge/commit/4794cfc90072f4ba2c1b05ba3881bb69d71ca3db))
 - **FEAT**(fledge_camera_2d): CameraFollowSystem — declare order + honour pixelPerfect. ([e7a77ef0](https://github.com/fledge-framework/fledge/commit/e7a77ef06b9f96d57dce359a2223212b37ea7f2d))
 - **FEAT**(fledge_render_2d): render interpolation between fixed ticks. ([6179b2d5](https://github.com/fledge-framework/fledge/commit/6179b2d5d1392d5719448521f100bbac640b6b7a))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))
 - **BREAKING** **FIX**(fledge_camera_2d): shake as a view offset, working screenToWorld, bounds at 1:1. ([cad20663](https://github.com/fledge-framework/fledge/commit/cad206632ad52d1fc5c57048269addfcafaea450))

#### `fledge_ecs` - `v0.7.0`

 - **FIX**(fledge_ecs): let SyncSystem inherit System defaults. ([e03de26c](https://github.com/fledge-framework/fledge/commit/e03de26ca162caee7277313a66612c1f7012a850))
 - **FIX**(fledge_ecs): keep the hierarchy consistent on despawn. ([13137a3e](https://github.com/fledge-framework/fledge/commit/13137a3eb9a0cb2e0c1f21b5ec7543ebcf35dd11))
 - **FIX**(fledge_ecs): honour change baselines in queryMut and set run conditions. ([f91c167b](https://github.com/fledge-framework/fledge/commit/f91c167be487abfd7a955b50e42d10ec36d8ccaa))
 - **FIX**(fledge_ecs): fire observers on despawn and bulk spawn. ([dcfbccb6](https://github.com/fledge-framework/fledge/commit/dcfbccb6c7ff1ae8880257d805ecbd7a5c4574a5))
 - **FIX**(fledge_ecs): make Added/Changed filters track per-system runs. ([7c9d7801](https://github.com/fledge-framework/fledge/commit/7c9d7801456c10d09c7472e7b6a5674b2aa93547))
 - **FIX**(fledge_ecs): fire OnExitState when leaving the state. ([cd5b4a58](https://github.com/fledge-framework/fledge/commit/cd5b4a58bfbda0098d8da319be1b3d904ffb295a))
 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**(fledge_ecs): explicit before/after overrides registration-order conflict edges. ([e698e92f](https://github.com/fledge-framework/fledge/commit/e698e92fd4bf396d60d5131f94ea3a0296b9f25e))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FIX**(fledge_input): fix timing issue for action resolution. ([62356b0d](https://github.com/fledge-framework/fledge/commit/62356b0d81db96018025579a544517bf85499de5))
 - **FIX**(fledge_ecs): create missing getters. ([e8f8ee3b](https://github.com/fledge-framework/fledge/commit/e8f8ee3ba27bf40d69599dda78ed27353f0cd7bb))
 - **FEAT**(fledge_ecs): handle machine idle time. ([a460f88a](https://github.com/fledge-framework/fledge/commit/a460f88a931e1af0941b906d5e0e464bf3cbbff5))
 - **FEAT**(fledge_tiled): extract collision from tilesets. ([a5db2352](https://github.com/fledge-framework/fledge/commit/a5db2352f66ec5d5f1d61a8541dbda9b3ff9b1a2))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**(fledge_ecs): add FixedTimestep.nudge for external clock sync. ([25e3cfe5](https://github.com/fledge-framework/fledge/commit/25e3cfe5b96a300e522013c9d58a1a2903305f8b))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_ecs): fan-out before/after when multiple systems share a name. ([664c4fd9](https://github.com/fledge-framework/fledge/commit/664c4fd9f8990ae17e2e1a3062c30a832ab24b9a))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(examples): add new drifter game demo. ([c126a144](https://github.com/fledge-framework/fledge/commit/c126a144fe20402104b01a259d4ee36a00327d92))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_save): create fledge_save package. ([48a3a327](https://github.com/fledge-framework/fledge/commit/48a3a327b9c0950ec320d7f805cce19bf7a300f6))
 - **FEAT**(fledge_ecs): add game checkpoint api. ([3b140dcc](https://github.com/fledge-framework/fledge/commit/3b140dccd5e52f9e6159e2059c161914cbafb6f7))
 - **FEAT**(fledge_physics): extract collision engine into new package. ([cc31acc0](https://github.com/fledge-framework/fledge/commit/cc31acc0a02159fd39fa0dcdb9655d223c4c0027))
 - **FEAT**(fledge_tiled): refactor TilemapSpawnConfig API. ([35b12d1e](https://github.com/fledge-framework/fledge/commit/35b12d1eaa72f7e703f6820b4e0f8d69452f509e))
 - **FEAT**(fledge_ecs): add advanced disposal functions. ([79479d10](https://github.com/fledge-framework/fledge/commit/79479d1027eb91954975c140c390f208a4f7de84))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))
 - **DOCS**(fledge_ecs): schedule_label comments reflect that App.tick drives fixed/extract/render. ([82292987](https://github.com/fledge-framework/fledge/commit/82292987556e9f327048a00c1a418c7f506b5b62))
 - **BREAKING** **FIX**(fledge_ecs): plugin lifecycle, App.dispose, run() yielding, strict single(). ([8251f76f](https://github.com/fledge-framework/fledge/commit/8251f76fc82597dc028287760b611cd2081443d0))

#### `fledge_net` - `v0.7.0`

 - **FIX**(fledge_net): close on host disconnect, allow full-host rejoins, resolve through encryption. ([4f873975](https://github.com/fledge-framework/fledge/commit/4f8739752c32f82c767abc83bb678a8474b36fb7))
 - **FIX**(fledge_net): smooth client interpolation with a decoupled render clock. ([b575aa35](https://github.com/fledge-framework/fledge/commit/b575aa35a49cb1da6f8154254c4bbd0c707c00d2))
 - **FIX**(fledge_net): latency fixes. ([c686b6ec](https://github.com/fledge-framework/fledge/commit/c686b6ec4727b4923f2e5a851718fb276bd1372c))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**(fledge_yarn): support for cinematics. ([1572d821](https://github.com/fledge-framework/fledge/commit/1572d8214899162164a8a5258bed8b713b8e4965))
 - **FEAT**(fledge_physics): weighted pathfinding and cost-aware path smoothing. ([42a8899d](https://github.com/fledge-framework/fledge/commit/42a8899d19b666779323c756e6e520b4c1d5e2c3))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**(fledge_ecs): add FixedTimestep.nudge for external clock sync. ([25e3cfe5](https://github.com/fledge-framework/fledge/commit/25e3cfe5b96a300e522013c9d58a1a2903305f8b))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_net): remediate documented limitations. ([203a78a6](https://github.com/fledge-framework/fledge/commit/203a78a6093897de435f9cf4528e3afcfab6073f))
 - **FEAT**(fledge_net): create net package. ([dfed40d6](https://github.com/fledge-framework/fledge/commit/dfed40d6773ee9371bca5cf432372e265bdc0bb0))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))
 - **BREAKING** **FIX**(fledge_net): hidden ancestors hide their descendants. ([db1a84d0](https://github.com/fledge-framework/fledge/commit/db1a84d05390675c2795d707780934ec8b01f6db))

#### `fledge_yarn` - `v0.7.0`

 - **FIX**(fledge_yarn): log malformed conditions. ([a3ffb06b](https://github.com/fledge-framework/fledge/commit/a3ffb06bff6c1d5f14d0376b2f107c549c9a2b70))
 - **FIX**(fledge_yarn): jump to a missing node no longer leaves the previous line up. ([33a6ac05](https://github.com/fledge-framework/fledge/commit/33a6ac054cab948839ec306e8a3363dd107e566d))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_render_2d): improve culling. ([966e8657](https://github.com/fledge-framework/fledge/commit/966e86576f4f886ad4afcd24958e607188e222f6))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**(fledge_yarn): support for cinematics. ([1572d821](https://github.com/fledge-framework/fledge/commit/1572d8214899162164a8a5258bed8b713b8e4965))
 - **FEAT**(fledge_audio): upgrade to leverage soloud. ([13964f36](https://github.com/fledge-framework/fledge/commit/13964f36394d8c39981071d5f03d9d8c153ce4c4))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_yarn): pausing command callbacks. ([8c117ce1](https://github.com/fledge-framework/fledge/commit/8c117ce153f3908816d22c3240c98e75b5a3af2d))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_yarn): create fledge_yarn for yarnspinner. ([9bbee221](https://github.com/fledge-framework/fledge/commit/9bbee2213966a290074b265ed60e57198d1047c0))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))
 - **DOCS**(fledge_yarn): tag grammar. ([6a4895fb](https://github.com/fledge-framework/fledge/commit/6a4895fbe48578d06d35c1afe446ba93f0411966))
 - **BREAKING** **FIX**(fledge_yarn): keep quoted strings, end once, hold on pausing commands. ([3cd78442](https://github.com/fledge-framework/fledge/commit/3cd78442c0a76f41522d0562092d003ea514a020))
 - **BREAKING** **FEAT**(fledge_yarn): event-driven dialogue layer. ([3f4be34d](https://github.com/fledge-framework/fledge/commit/3f4be34d8104c2cc2a56030dfe7012421304900b))

#### `fledge_audio` - `v0.7.0`

 - **FIX**(fledge_audio): mix spatial audio in world space and report source endings. ([f78de16f](https://github.com/fledge-framework/fledge/commit/f78de16f9d9a2b5ba3f36e7b6a1d808c5fd5ccf0))
 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**: bump lower bound of fledge_audio. ([1198dd84](https://github.com/fledge-framework/fledge/commit/1198dd8466d6d92b11ebc5b9127e6ce66c92edab))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**(fledge_tiled): extract collision from tilesets. ([a5db2352](https://github.com/fledge-framework/fledge/commit/a5db2352f66ec5d5f1d61a8541dbda9b3ff9b1a2))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**(fledge_audio): upgrade to leverage soloud. ([13964f36](https://github.com/fledge-framework/fledge/commit/13964f36394d8c39981071d5f03d9d8c153ce4c4))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_audio): expose systemName on AudioInitSystem and SpatialAudioSystem. ([d79dce3c](https://github.com/fledge-framework/fledge/commit/d79dce3c6c224120e5cf6b7b79454a681d6b5f14))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_tiled): refactor TilemapSpawnConfig API. ([35b12d1e](https://github.com/fledge-framework/fledge/commit/35b12d1eaa72f7e703f6820b4e0f8d69452f509e))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))

#### `fledge_calendar` - `v0.7.0`

 - **FIX**(fledge_calendar): fail loudly without WallTime, format non-24h days. ([09e613f6](https://github.com/fledge-framework/fledge/commit/09e613f6c92b56e8fb4fec470419f4114e31a592))
 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**(fledge_calendar): order CalendarSystem after wallTimeUpdate. ([f61ce1e6](https://github.com/fledge-framework/fledge/commit/f61ce1e69778a51f5f4ea3befe0e4b99076ee763))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: adopt CalendarPlugin. ([815b8576](https://github.com/fledge-framework/fledge/commit/815b8576d960004c378f99d379a4d0949dbdf8ef))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))

#### `fledge_debug` - `v0.7.0`

 - **FIX**(fledge_debug): draw the frustum the widget actually shows. ([23ca8a2d](https://github.com/fledge-framework/fledge/commit/23ca8a2d3acfda7669bcd4885feef90a09801c7b))
 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**(fledge_debug): keep an existing DebugConfig instead of overwriting it. ([8c5b3725](https://github.com/fledge-framework/fledge/commit/8c5b3725bbfd84a86f4f0d87d6a77840ab12f242))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_render_2d): improve culling. ([966e8657](https://github.com/fledge-framework/fledge/commit/966e86576f4f886ad4afcd24958e607188e222f6))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_debug): auto-refresh ScheduleOrderingReport on first tick. ([0e152b9e](https://github.com/fledge-framework/fledge/commit/0e152b9e6eaf00f9f30096d9f61c1f2c7a0c777a))
 - **FEAT**(fledge_debug): optional overlay and a standalone stats plugin. ([aef458b1](https://github.com/fledge-framework/fledge/commit/aef458b1ff7ceb251fbb46c7d9fbe244f43939f0))
 - **FEAT**: camera-aware widget render path. ([6b8ff1b7](https://github.com/fledge-framework/fledge/commit/6b8ff1b7f1eaf6a930a73d7a4c5a0c4e26f12385))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))

#### `fledge_ecs_annotations` - `v0.7.0`

 - **FIX**(fledge_ecs): fire observers on despawn and bulk spawn. ([dcfbccb6](https://github.com/fledge-framework/fledge/commit/dcfbccb6c7ff1ae8880257d805ecbd7a5c4574a5))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))

#### `fledge_ecs_generator` - `v0.7.0`

 - **FIX**(fledge_ecs_generator): apply Commands and await async systems. ([4c168c54](https://github.com/fledge-framework/fledge/commit/4c168c543a6c0d094f0530cc556dab2080df5610))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): create net package. ([dfed40d6](https://github.com/fledge-framework/fledge/commit/dfed40d6773ee9371bca5cf432372e265bdc0bb0))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))
 - **DOCS**(fledge_ecs_generator): match the generator doc comment to real output. ([5f1285ee](https://github.com/fledge-framework/fledge/commit/5f1285eef9a0ced03c6e1e7f0f29eee3a7fda135))

#### `fledge_input` - `v0.7.0`

 - **FIX**(fledge_input): release every mouse button, restore contexts, honour priority. ([176a8df3](https://github.com/fledge-framework/fledge/commit/176a8df36b5d0402356754c1b5b7521450909ff7))
 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FIX**(fledge_input): persist input transition flags through the entire frame. ([f96f8ca2](https://github.com/fledge-framework/fledge/commit/f96f8ca2e5ae6f5cbf502d422014321d93ce4a1a))
 - **FIX**(fledge_input): fix timing issue for action resolution. ([62356b0d](https://github.com/fledge-framework/fledge/commit/62356b0d81db96018025579a544517bf85499de5))
 - **FEAT**(fledge_input): extend focus bridge. ([d70ab856](https://github.com/fledge-framework/fledge/commit/d70ab856af51a16f187da4c1bd7bf619e0c92f08))
 - **FEAT**(fledge_render_2d): improve culling. ([966e8657](https://github.com/fledge-framework/fledge/commit/966e86576f4f886ad4afcd24958e607188e222f6))
 - **FEAT**(fledge_tiled): extract collision from tilesets. ([a5db2352](https://github.com/fledge-framework/fledge/commit/a5db2352f66ec5d5f1d61a8541dbda9b3ff9b1a2))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**(fledge_audio): upgrade to leverage soloud. ([13964f36](https://github.com/fledge-framework/fledge/commit/13964f36394d8c39981071d5f03d9d8c153ce4c4))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(examples): add new drifter game demo. ([c126a144](https://github.com/fledge-framework/fledge/commit/c126a144fe20402104b01a259d4ee36a00327d92))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_net): create net package. ([dfed40d6](https://github.com/fledge-framework/fledge/commit/dfed40d6773ee9371bca5cf432372e265bdc0bb0))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))

#### `fledge_lighting_2d` - `v0.7.0`

 - **FIX**(fledge_lighting_2d): camera-aware additive light pass fills the visible world viewport. ([23bae1ac](https://github.com/fledge-framework/fledge/commit/23bae1acc5358817a3a469ee8000f379e21e46bf))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**(fledge_audio): upgrade to leverage soloud. ([13964f36](https://github.com/fledge-framework/fledge/commit/13964f36394d8c39981071d5f03d9d8c153ce4c4))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_lighting_2d): optional AmbientLight.bounds clips the overSprites multiply. ([e6429852](https://github.com/fledge-framework/fledge/commit/e64298524b34d0fcdcb755570f262c67727e75c1))
 - **FEAT**: camera-aware widget render path. ([6b8ff1b7](https://github.com/fledge-framework/fledge/commit/6b8ff1b7f1eaf6a930a73d7a4c5a0c4e26f12385))
 - **FEAT**(fledge_lighting_2d): AmbientBlend.overSprites — ambient darkens sprites too. ([7d0c33db](https://github.com/fledge-framework/fledge/commit/7d0c33dbb8bb5bb6a89b4d73faecfa04d2780a07))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))
 - **DOCS**(*): fix stale comments in fledge_lighting_2d and drifter. ([80c17633](https://github.com/fledge-framework/fledge/commit/80c176333b2d34f78dfb6a4239c154b9f8030e55))

#### `fledge_net_steam` - `v0.7.0`

 - **FIX**(fledge_net_steam): bound session requests and leave the lobby on join errors. ([df2d3e2b](https://github.com/fledge-framework/fledge/commit/df2d3e2bade8ec408b32fad8dbfa9532d9cbfe29))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))

#### `fledge_particles` - `v0.7.0`

 - **FIX**(fledge_particles): register the extractor whatever the plugin order. ([310c5c29](https://github.com/fledge-framework/fledge/commit/310c5c29dbd70659d1b0434c51f9308d444d825b))
 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_particles): cull particles outside the camera view. ([435f3937](https://github.com/fledge-framework/fledge/commit/435f3937b8ec37d7a1af92e5366491235085bb57))
 - **FEAT**(fledge_render_2d): improve culling. ([966e8657](https://github.com/fledge-framework/fledge/commit/966e86576f4f886ad4afcd24958e607188e222f6))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))

#### `fledge_physics` - `v0.7.0`

 - **FIX**(fledge_physics): tight rotated bounds, cheap hasPath, fixed-mode sets. ([1049b723](https://github.com/fledge-framework/fledge/commit/1049b7238f6e01f1cb767ed812582bc561d354ab))
 - **FIX**(fledge_physics): yieldAfter counts blocked contact, not only overlap. ([f6bbb220](https://github.com/fledge-framework/fledge/commit/f6bbb220509bead9664c04cc4dd97051f0290eda))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_physics): add flutter dependency to package. ([c6608ee5](https://github.com/fledge-framework/fledge/commit/c6608ee5128672c4ec03963ca3b4abd8c507673f))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**(fledge_physics): prevent clipping during pathfinding. ([dac8ffaf](https://github.com/fledge-framework/fledge/commit/dac8ffaf3c8dd2815a626ae80694561823530a08))
 - **FEAT**(fledge_physics): weighted pathfinding and cost-aware path smoothing. ([42a8899d](https://github.com/fledge-framework/fledge/commit/42a8899d19b666779323c756e6e520b4c1d5e2c3))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**(fledge_physics): expose systemName on collision + velocity systems. ([4b0e8a58](https://github.com/fledge-framework/fledge/commit/4b0e8a58c63ef1cc974419c777e23d5a8fefa1e4))
 - **FEAT**(fledge_physics): yieldAfter — pass-through after sustained contact. ([5af431e0](https://github.com/fledge-framework/fledge/commit/5af431e06101b6f80350c8e23416c58eedc202bb))
 - **FEAT**(fledge_physics): opt-in dynamic-vs-dynamic blocking. ([e264f586](https://github.com/fledge-framework/fledge/commit/e264f586778836cd99b64aafdbdadb056455885f))
 - **FEAT**(fledge_physics): fixed-step integration + resolution. ([271b41de](https://github.com/fledge-framework/fledge/commit/271b41defa06e8e9f58218e39fed4c6ab3989720))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(examples): add new drifter game demo. ([c126a144](https://github.com/fledge-framework/fledge/commit/c126a144fe20402104b01a259d4ee36a00327d92))
 - **FEAT**(fledge_physics): extract collision engine into new package. ([cc31acc0](https://github.com/fledge-framework/fledge/commit/cc31acc0a02159fd39fa0dcdb9655d223c4c0027))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))

#### `fledge_render_2d` - `v0.7.0`

 - **REFACTOR**(fledge_render): combine core systems from fledge_render_flutter. ([4126c272](https://github.com/fledge-framework/fledge/commit/4126c272f2ddd3a198a285c5a80afdbea79aa126))
 - **FIX**(fledge_render_2d): make GlobalTransform2D.inverse return the inverse. ([61a4e8a4](https://github.com/fledge-framework/fledge/commit/61a4e8a4cd348c3f371d1fffbc4a4a019f17fbf0))
 - **FIX**(fledge_render_2d): canvas drawer supports mirrored sprites. ([fc2b3440](https://github.com/fledge-framework/fledge/commit/fc2b34408cf39ea7ff0420a6b7100ff9ba41cad0))
 - **FIX**(fledge_render_2d): Y-sort keeps working past y = 100 px. ([faa9fd04](https://github.com/fledge-framework/fledge/commit/faa9fd04fab36f3a2b61b74155d9223eaba802ce))
 - **FIX**(fledge_render_2d): sprite anchor formula no longer mirrored. ([dcd70d65](https://github.com/fledge-framework/fledge/commit/dcd70d65a88a2cc51aaf9a4b95e0fecfb15ff91f))
 - **FIX**(fledge_render_2d): atlas/tile frames no longer draw offset by source position. ([c786f3b2](https://github.com/fledge-framework/fledge/commit/c786f3b28483f558c18078eb4417eff40a00850e))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**(fledge_render_2d): cull atlas sprites like plain sprites. ([2b1bb4df](https://github.com/fledge-framework/fledge/commit/2b1bb4dfd8a1e691424fd1ded780953485f9551a))
 - **FEAT**(fledge_render_2d): improve culling. ([966e8657](https://github.com/fledge-framework/fledge/commit/966e86576f4f886ad4afcd24958e607188e222f6))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**(fledge_physics): prevent clipping during pathfinding. ([dac8ffaf](https://github.com/fledge-framework/fledge/commit/dac8ffaf3c8dd2815a626ae80694561823530a08))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_render_2d): expose systemName on transform / animation / transition systems. ([5813ff7a](https://github.com/fledge-framework/fledge/commit/5813ff7a34bba1623b5abdec394d8bcfa304e6d6))
 - **FEAT**(fledge_render_2d): pixel-snap the camera canvas offset when pixelPerfect. ([3137dc16](https://github.com/fledge-framework/fledge/commit/3137dc16178b2d2c35eb4aa9d6d08eae13ccdbe9))
 - **FEAT**: camera-aware widget render path. ([6b8ff1b7](https://github.com/fledge-framework/fledge/commit/6b8ff1b7f1eaf6a930a73d7a4c5a0c4e26f12385))
 - **FEAT**(fledge_render_2d): AtlasSprite gains an anchor field. ([d713ff50](https://github.com/fledge-framework/fledge/commit/d713ff5000a9673fc30b363d7833cf5a1a6be499))
 - **FEAT**(fledge_render_2d): render interpolation between fixed ticks. ([6179b2d5](https://github.com/fledge-framework/fledge/commit/6179b2d5d1392d5719448521f100bbac640b6b7a))
 - **FEAT**(fledge_render_2d): emit TransitionCompleted when a fade transition finishes. ([85d3f225](https://github.com/fledge-framework/fledge/commit/85d3f2250be1ff9b952a5ddf50c6db9eaf78a097))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_save): create fledge_save package. ([48a3a327](https://github.com/fledge-framework/fledge/commit/48a3a327b9c0950ec320d7f805cce19bf7a300f6))
 - **FEAT**(fledge_tiled): add CulledTilemapExtractor. ([8ad8e658](https://github.com/fledge-framework/fledge/commit/8ad8e65817ad8074f55929085fe6d8747da6e114))
 - **FEAT**(fledge_tiled): refactor TilemapSpawnConfig API. ([35b12d1e](https://github.com/fledge-framework/fledge/commit/35b12d1eaa72f7e703f6820b4e0f8d69452f509e))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))

#### `fledge_save` - `v0.7.0`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_audio): upgrade to leverage soloud. ([13964f36](https://github.com/fledge-framework/fledge/commit/13964f36394d8c39981071d5f03d9d8c153ce4c4))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: adopt CalendarPlugin. ([815b8576](https://github.com/fledge-framework/fledge/commit/815b8576d960004c378f99d379a4d0949dbdf8ef))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_save): create fledge_save package. ([48a3a327](https://github.com/fledge-framework/fledge/commit/48a3a327b9c0950ec320d7f805cce19bf7a300f6))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))
 - **DOCS**(fledge_save): fix stale SaveManager and library examples. ([408ae731](https://github.com/fledge-framework/fledge/commit/408ae7313dc2cf4ef464916e5c0a50e893bc6e0d))

#### `fledge_tiled` - `v0.7.0`

 - **REFACTOR**(fledge_tiled): depend on fledge_render_2d instead of the fledge_render shim. ([72becfe6](https://github.com/fledge-framework/fledge/commit/72becfe6bef448a30cf5a4d59bbd6fed651678a9))
 - **REFACTOR**(fledge_render): combine core systems from fledge_render_flutter. ([4126c272](https://github.com/fledge-framework/fledge/commit/4126c272f2ddd3a198a285c5a80afdbea79aa126))
 - **FIX**(fledge_tiled): parallax like Tiled, image-collection tiles, tile offsets. ([1efa710e](https://github.com/fledge-framework/fledge/commit/1efa710ebc5e0744149bc10df2e9c5dbd763739b))
 - **FIX**(fledge_tiled): render infinite maps, size oversized tiles, implement TsxLoader. ([bae96543](https://github.com/fledge-framework/fledge/commit/bae965435950188f7058d80c04afc89420f3c894))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**(fledge_render_2d): improve culling. ([966e8657](https://github.com/fledge-framework/fledge/commit/966e86576f4f886ad4afcd24958e607188e222f6))
 - **FEAT**(fledge_tiled): extract collision from tilesets. ([a5db2352](https://github.com/fledge-framework/fledge/commit/a5db2352f66ec5d5f1d61a8541dbda9b3ff9b1a2))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**(fledge_physics): weighted pathfinding and cost-aware path smoothing. ([42a8899d](https://github.com/fledge-framework/fledge/commit/42a8899d19b666779323c756e6e520b4c1d5e2c3))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_tiled): expose TilemapSpawnSystem.systemName. ([3b5ea9f9](https://github.com/fledge-framework/fledge/commit/3b5ea9f9c3e4adaf9f2694133b83b188a3b73aa1))
 - **FEAT**(fledge_tiled): emit ExtractedSprite so tiles draw through FledgeRenderView. ([76ad87f7](https://github.com/fledge-framework/fledge/commit/76ad87f7c9f3b5a8d1bb64bc9847931924227b44))
 - **FEAT**(fledge_tiled): read tilemaps from Assets<TilemapAsset>. ([eb0515f2](https://github.com/fledge-framework/fledge/commit/eb0515f27f746f536a4060683b178716b9d40b3c))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_tiled): add CulledTilemapExtractor. ([8ad8e658](https://github.com/fledge-framework/fledge/commit/8ad8e65817ad8074f55929085fe6d8747da6e114))
 - **FEAT**(fledge_tiled): add support for pathfinding. ([23ba2e0c](https://github.com/fledge-framework/fledge/commit/23ba2e0cad68aabb2bc8a7a0fab52c0af96acd58))
 - **FEAT**(fledge_tiled): enable class based tile sorting. ([291d9a12](https://github.com/fledge-framework/fledge/commit/291d9a12ed5d99912919497b024e7fdd286ae1ce))
 - **FEAT**(fledge_tiled): refactor TilemapSpawnConfig API. ([35b12d1e](https://github.com/fledge-framework/fledge/commit/35b12d1eaa72f7e703f6820b4e0f8d69452f509e))
 - **FEAT**(fledge_render): use layer enums rather than magic numbers. ([b7337885](https://github.com/fledge-framework/fledge/commit/b73378851a5fc04ea34893e6cd1690a6067b3a46))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))

#### `fledge_tween` - `v0.7.0`

 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))

#### `fledge_ui` - `v0.7.0`

 - **FIX**(fledge_ui): apply UiImage tint colours, add overlay repaint. ([b3f2d33d](https://github.com/fledge-framework/fledge/commit/b3f2d33d123b641d18850206c4827447c77126f3))
 - **FIX**(fledge_ui): make FledgeUiOverlay draw extracted elements. ([1ed52f1d](https://github.com/fledge-framework/fledge/commit/1ed52f1d8a2774eab71fd8d5951a5ed53d5d352b))
 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_ui): placement mode. ([7a378aef](https://github.com/fledge-framework/fledge/commit/7a378aeff4540bfc9b78f4755875ac02fbd153d0))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))

#### `fledge_window` - `v0.7.0`

 - **FIX**(fledge_window): report real display refresh rates. ([404e7d4c](https://github.com/fledge-framework/fledge/commit/404e7d4c61537b5d68394efc1907d2b3531f6b78))
 - **FIX**(fledge_window): stop awaiting window_manager every frame. ([2266e92f](https://github.com/fledge-framework/fledge/commit/2266e92f82f20df492fe708f7d94c726d8ba654c))
 - **FIX**(fledge_window): report OS focus, resize and move changes. ([0378ca85](https://github.com/fledge-framework/fledge/commit/0378ca8539f156dfc6f017d00459e02eb3ee4fcb))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_window): expose WindowInitSystem.systemName. ([1c1bd0c7](https://github.com/fledge-framework/fledge/commit/1c1bd0c71295a6208389ac2d45994978507755cb))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(examples): add new drifter game demo. ([c126a144](https://github.com/fledge-framework/fledge/commit/c126a144fe20402104b01a259d4ee36a00327d92))
 - **FEAT**(fledge_window): add error handling. ([affec7da](https://github.com/fledge-framework/fledge/commit/affec7dacc8dd5821d09adc6e96ebc2258a64f5f))
 - **FEAT**(fledge_net): create net package. ([dfed40d6](https://github.com/fledge-framework/fledge/commit/dfed40d6773ee9371bca5cf432372e265bdc0bb0))
 - **FEAT**(fledge_window): add close command on app. ([d30f616f](https://github.com/fledge-framework/fledge/commit/d30f616feda5b50af3217ea505815ceb8c360705))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))
 - **DOCS**(*): correct README quick starts and point links at the new docs. ([50d6e5da](https://github.com/fledge-framework/fledge/commit/50d6e5da2e8bf3eb220be3782b66e0b74438fd06))


## 2026-11-24

### Changes

---

Packages with breaking changes:

 - [`fledge_yarn` - `v0.6.0`](#fledge_yarn---v060)

Packages with other changes:

 - [`fledge_assets` - `v0.6.0`](#fledge_assets---v060)
 - [`fledge_audio` - `v0.6.0`](#fledge_audio---v060)
 - [`fledge_calendar` - `v0.6.0`](#fledge_calendar---v060)
 - [`fledge_camera_2d` - `v0.6.0`](#fledge_camera_2d---v060)
 - [`fledge_debug` - `v0.6.0`](#fledge_debug---v060)
 - [`fledge_ecs` - `v0.6.0`](#fledge_ecs---v060)
 - [`fledge_ecs_annotations` - `v0.6.0`](#fledge_ecs_annotations---v060)
 - [`fledge_ecs_generator` - `v0.6.0`](#fledge_ecs_generator---v060)
 - [`fledge_input` - `v0.6.0`](#fledge_input---v060)
 - [`fledge_lighting_2d` - `v0.6.0`](#fledge_lighting_2d---v060)
 - [`fledge_net` - `v0.6.0`](#fledge_net---v060)
 - [`fledge_net_steam` - `v0.6.0`](#fledge_net_steam---v060)
 - [`fledge_particles` - `v0.6.0`](#fledge_particles---v060)
 - [`fledge_physics` - `v0.6.0`](#fledge_physics---v060)
 - [`fledge_render_2d` - `v0.6.0`](#fledge_render_2d---v060)
 - [`fledge_save` - `v0.6.0`](#fledge_save---v060)
 - [`fledge_tiled` - `v0.6.0`](#fledge_tiled---v060)
 - [`fledge_tween` - `v0.6.0`](#fledge_tween---v060)
 - [`fledge_ui` - `v0.6.0`](#fledge_ui---v060)
 - [`fledge_window` - `v0.6.0`](#fledge_window---v060)

---

#### `fledge_yarn` - `v0.6.0`

 - **FIX**(fledge_yarn): jump to a missing node no longer leaves the previous line up. ([33a6ac05](https://github.com/fledge-framework/fledge/commit/33a6ac054cab948839ec306e8a3363dd107e566d))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_render_2d): improve culling. ([966e8657](https://github.com/fledge-framework/fledge/commit/966e86576f4f886ad4afcd24958e607188e222f6))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**(fledge_yarn): support for cinematics. ([1572d821](https://github.com/fledge-framework/fledge/commit/1572d8214899162164a8a5258bed8b713b8e4965))
 - **FEAT**(fledge_audio): upgrade to leverage soloud. ([13964f36](https://github.com/fledge-framework/fledge/commit/13964f36394d8c39981071d5f03d9d8c153ce4c4))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_yarn): pausing command callbacks. ([8c117ce1](https://github.com/fledge-framework/fledge/commit/8c117ce153f3908816d22c3240c98e75b5a3af2d))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_yarn): create fledge_yarn for yarnspinner. ([9bbee221](https://github.com/fledge-framework/fledge/commit/9bbee2213966a290074b265ed60e57198d1047c0))
 - **DOCS**(fledge_yarn): tag grammar. ([6a4895fb](https://github.com/fledge-framework/fledge/commit/6a4895fbe48578d06d35c1afe446ba93f0411966))
 - **BREAKING** **FEAT**(fledge_yarn): event-driven dialogue layer. ([3f4be34d](https://github.com/fledge-framework/fledge/commit/3f4be34d8104c2cc2a56030dfe7012421304900b))

#### `fledge_assets` - `v0.6.0`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_audio` - `v0.6.0`

 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**: bump lower bound of fledge_audio. ([1198dd84](https://github.com/fledge-framework/fledge/commit/1198dd8466d6d92b11ebc5b9127e6ce66c92edab))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**(fledge_tiled): extract collision from tilesets. ([a5db2352](https://github.com/fledge-framework/fledge/commit/a5db2352f66ec5d5f1d61a8541dbda9b3ff9b1a2))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**(fledge_audio): upgrade to leverage soloud. ([13964f36](https://github.com/fledge-framework/fledge/commit/13964f36394d8c39981071d5f03d9d8c153ce4c4))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_audio): expose systemName on AudioInitSystem and SpatialAudioSystem. ([d79dce3c](https://github.com/fledge-framework/fledge/commit/d79dce3c6c224120e5cf6b7b79454a681d6b5f14))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_tiled): refactor TilemapSpawnConfig API. ([35b12d1e](https://github.com/fledge-framework/fledge/commit/35b12d1eaa72f7e703f6820b4e0f8d69452f509e))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

#### `fledge_calendar` - `v0.6.0`

 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**(fledge_calendar): order CalendarSystem after wallTimeUpdate. ([f61ce1e6](https://github.com/fledge-framework/fledge/commit/f61ce1e69778a51f5f4ea3befe0e4b99076ee763))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: adopt CalendarPlugin. ([815b8576](https://github.com/fledge-framework/fledge/commit/815b8576d960004c378f99d379a4d0949dbdf8ef))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_camera_2d` - `v0.6.0`

 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**(fledge_camera_2d): CameraFollow.marker stays quiet until a target appears. ([d1894e64](https://github.com/fledge-framework/fledge/commit/d1894e645754d3a9418e273826b8d14a80e52c2f))
 - **FIX**(fledge_camera_2d): order ActiveCameraViewSystem after transform_propagate. ([42af6b8b](https://github.com/fledge-framework/fledge/commit/42af6b8baf01bcfc3f58d0c37392cc1912d7a4d1))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**(fledge_yarn): support for cinematics. ([1572d821](https://github.com/fledge-framework/fledge/commit/1572d8214899162164a8a5258bed8b713b8e4965))
 - **FEAT**(fledge_audio): upgrade to leverage soloud. ([13964f36](https://github.com/fledge-framework/fledge/commit/13964f36394d8c39981071d5f03d9d8c153ce4c4))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_camera_2d): expose CameraFollowSystem.systemName and ActiveCameraViewSystem.systemName. ([d42ccd1e](https://github.com/fledge-framework/fledge/commit/d42ccd1eb519d38eb71fc91e7787914cada05f75))
 - **FEAT**(fledge_render_2d): pixel-snap the camera canvas offset when pixelPerfect. ([3137dc16](https://github.com/fledge-framework/fledge/commit/3137dc16178b2d2c35eb4aa9d6d08eae13ccdbe9))
 - **FEAT**: camera-aware widget render path. ([6b8ff1b7](https://github.com/fledge-framework/fledge/commit/6b8ff1b7f1eaf6a930a73d7a4c5a0c4e26f12385))
 - **FEAT**(fledge_camera_2d): CameraFollow updates root camera GlobalTransform2D + marker target. ([4794cfc9](https://github.com/fledge-framework/fledge/commit/4794cfc90072f4ba2c1b05ba3881bb69d71ca3db))
 - **FEAT**(fledge_camera_2d): CameraFollowSystem — declare order + honour pixelPerfect. ([e7a77ef0](https://github.com/fledge-framework/fledge/commit/e7a77ef06b9f96d57dce359a2223212b37ea7f2d))
 - **FEAT**(fledge_render_2d): render interpolation between fixed ticks. ([6179b2d5](https://github.com/fledge-framework/fledge/commit/6179b2d5d1392d5719448521f100bbac640b6b7a))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_debug` - `v0.6.0`

 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**(fledge_debug): keep an existing DebugConfig instead of overwriting it. ([8c5b3725](https://github.com/fledge-framework/fledge/commit/8c5b3725bbfd84a86f4f0d87d6a77840ab12f242))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_render_2d): improve culling. ([966e8657](https://github.com/fledge-framework/fledge/commit/966e86576f4f886ad4afcd24958e607188e222f6))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_debug): auto-refresh ScheduleOrderingReport on first tick. ([0e152b9e](https://github.com/fledge-framework/fledge/commit/0e152b9e6eaf00f9f30096d9f61c1f2c7a0c777a))
 - **FEAT**(fledge_debug): optional overlay and a standalone stats plugin. ([aef458b1](https://github.com/fledge-framework/fledge/commit/aef458b1ff7ceb251fbb46c7d9fbe244f43939f0))
 - **FEAT**: camera-aware widget render path. ([6b8ff1b7](https://github.com/fledge-framework/fledge/commit/6b8ff1b7f1eaf6a930a73d7a4c5a0c4e26f12385))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_ecs` - `v0.6.0`

 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**(fledge_ecs): explicit before/after overrides registration-order conflict edges. ([e698e92f](https://github.com/fledge-framework/fledge/commit/e698e92fd4bf396d60d5131f94ea3a0296b9f25e))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FIX**(fledge_input): fix timing issue for action resolution. ([62356b0d](https://github.com/fledge-framework/fledge/commit/62356b0d81db96018025579a544517bf85499de5))
 - **FIX**(fledge_ecs): create missing getters. ([e8f8ee3b](https://github.com/fledge-framework/fledge/commit/e8f8ee3ba27bf40d69599dda78ed27353f0cd7bb))
 - **FEAT**(fledge_ecs): handle machine idle time. ([a460f88a](https://github.com/fledge-framework/fledge/commit/a460f88a931e1af0941b906d5e0e464bf3cbbff5))
 - **FEAT**(fledge_tiled): extract collision from tilesets. ([a5db2352](https://github.com/fledge-framework/fledge/commit/a5db2352f66ec5d5f1d61a8541dbda9b3ff9b1a2))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**(fledge_ecs): add FixedTimestep.nudge for external clock sync. ([25e3cfe5](https://github.com/fledge-framework/fledge/commit/25e3cfe5b96a300e522013c9d58a1a2903305f8b))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_ecs): fan-out before/after when multiple systems share a name. ([664c4fd9](https://github.com/fledge-framework/fledge/commit/664c4fd9f8990ae17e2e1a3062c30a832ab24b9a))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(examples): add new drifter game demo. ([c126a144](https://github.com/fledge-framework/fledge/commit/c126a144fe20402104b01a259d4ee36a00327d92))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_save): create fledge_save package. ([48a3a327](https://github.com/fledge-framework/fledge/commit/48a3a327b9c0950ec320d7f805cce19bf7a300f6))
 - **FEAT**(fledge_ecs): add game checkpoint api. ([3b140dcc](https://github.com/fledge-framework/fledge/commit/3b140dccd5e52f9e6159e2059c161914cbafb6f7))
 - **FEAT**(fledge_physics): extract collision engine into new package. ([cc31acc0](https://github.com/fledge-framework/fledge/commit/cc31acc0a02159fd39fa0dcdb9655d223c4c0027))
 - **FEAT**(fledge_tiled): refactor TilemapSpawnConfig API. ([35b12d1e](https://github.com/fledge-framework/fledge/commit/35b12d1eaa72f7e703f6820b4e0f8d69452f509e))
 - **FEAT**(fledge_ecs): add advanced disposal functions. ([79479d10](https://github.com/fledge-framework/fledge/commit/79479d1027eb91954975c140c390f208a4f7de84))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))
 - **DOCS**(fledge_ecs): schedule_label comments reflect that App.tick drives fixed/extract/render. ([82292987](https://github.com/fledge-framework/fledge/commit/82292987556e9f327048a00c1a418c7f506b5b62))

#### `fledge_ecs_annotations` - `v0.6.0`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

#### `fledge_ecs_generator` - `v0.6.0`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): create net package. ([dfed40d6](https://github.com/fledge-framework/fledge/commit/dfed40d6773ee9371bca5cf432372e265bdc0bb0))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

#### `fledge_input` - `v0.6.0`

 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FIX**(fledge_input): persist input transition flags through the entire frame. ([f96f8ca2](https://github.com/fledge-framework/fledge/commit/f96f8ca2e5ae6f5cbf502d422014321d93ce4a1a))
 - **FIX**(fledge_input): fix timing issue for action resolution. ([62356b0d](https://github.com/fledge-framework/fledge/commit/62356b0d81db96018025579a544517bf85499de5))
 - **FEAT**(fledge_input): extend focus bridge. ([d70ab856](https://github.com/fledge-framework/fledge/commit/d70ab856af51a16f187da4c1bd7bf619e0c92f08))
 - **FEAT**(fledge_render_2d): improve culling. ([966e8657](https://github.com/fledge-framework/fledge/commit/966e86576f4f886ad4afcd24958e607188e222f6))
 - **FEAT**(fledge_tiled): extract collision from tilesets. ([a5db2352](https://github.com/fledge-framework/fledge/commit/a5db2352f66ec5d5f1d61a8541dbda9b3ff9b1a2))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**(fledge_audio): upgrade to leverage soloud. ([13964f36](https://github.com/fledge-framework/fledge/commit/13964f36394d8c39981071d5f03d9d8c153ce4c4))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(examples): add new drifter game demo. ([c126a144](https://github.com/fledge-framework/fledge/commit/c126a144fe20402104b01a259d4ee36a00327d92))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_net): create net package. ([dfed40d6](https://github.com/fledge-framework/fledge/commit/dfed40d6773ee9371bca5cf432372e265bdc0bb0))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

#### `fledge_lighting_2d` - `v0.6.0`

 - **FIX**(fledge_lighting_2d): camera-aware additive light pass fills the visible world viewport. ([23bae1ac](https://github.com/fledge-framework/fledge/commit/23bae1acc5358817a3a469ee8000f379e21e46bf))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**(fledge_audio): upgrade to leverage soloud. ([13964f36](https://github.com/fledge-framework/fledge/commit/13964f36394d8c39981071d5f03d9d8c153ce4c4))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_lighting_2d): optional AmbientLight.bounds clips the overSprites multiply. ([e6429852](https://github.com/fledge-framework/fledge/commit/e64298524b34d0fcdcb755570f262c67727e75c1))
 - **FEAT**: camera-aware widget render path. ([6b8ff1b7](https://github.com/fledge-framework/fledge/commit/6b8ff1b7f1eaf6a930a73d7a4c5a0c4e26f12385))
 - **FEAT**(fledge_lighting_2d): AmbientBlend.overSprites — ambient darkens sprites too. ([7d0c33db](https://github.com/fledge-framework/fledge/commit/7d0c33dbb8bb5bb6a89b4d73faecfa04d2780a07))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_net` - `v0.6.0`

 - **FIX**(fledge_net): smooth client interpolation with a decoupled render clock. ([b575aa35](https://github.com/fledge-framework/fledge/commit/b575aa35a49cb1da6f8154254c4bbd0c707c00d2))
 - **FIX**(fledge_net): latency fixes. ([c686b6ec](https://github.com/fledge-framework/fledge/commit/c686b6ec4727b4923f2e5a851718fb276bd1372c))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**(fledge_yarn): support for cinematics. ([1572d821](https://github.com/fledge-framework/fledge/commit/1572d8214899162164a8a5258bed8b713b8e4965))
 - **FEAT**(fledge_physics): weighted pathfinding and cost-aware path smoothing. ([42a8899d](https://github.com/fledge-framework/fledge/commit/42a8899d19b666779323c756e6e520b4c1d5e2c3))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**(fledge_ecs): add FixedTimestep.nudge for external clock sync. ([25e3cfe5](https://github.com/fledge-framework/fledge/commit/25e3cfe5b96a300e522013c9d58a1a2903305f8b))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_net): remediate documented limitations. ([203a78a6](https://github.com/fledge-framework/fledge/commit/203a78a6093897de435f9cf4528e3afcfab6073f))
 - **FEAT**(fledge_net): create net package. ([dfed40d6](https://github.com/fledge-framework/fledge/commit/dfed40d6773ee9371bca5cf432372e265bdc0bb0))

#### `fledge_net_steam` - `v0.6.0`

 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))

#### `fledge_particles` - `v0.6.0`

 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_render_2d): improve culling. ([966e8657](https://github.com/fledge-framework/fledge/commit/966e86576f4f886ad4afcd24958e607188e222f6))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_physics` - `v0.6.0`

 - **FIX**(fledge_physics): yieldAfter counts blocked contact, not only overlap. ([f6bbb220](https://github.com/fledge-framework/fledge/commit/f6bbb220509bead9664c04cc4dd97051f0290eda))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_physics): add flutter dependency to package. ([c6608ee5](https://github.com/fledge-framework/fledge/commit/c6608ee5128672c4ec03963ca3b4abd8c507673f))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**(fledge_physics): prevent clipping during pathfinding. ([dac8ffaf](https://github.com/fledge-framework/fledge/commit/dac8ffaf3c8dd2815a626ae80694561823530a08))
 - **FEAT**(fledge_physics): weighted pathfinding and cost-aware path smoothing. ([42a8899d](https://github.com/fledge-framework/fledge/commit/42a8899d19b666779323c756e6e520b4c1d5e2c3))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**(fledge_physics): expose systemName on collision + velocity systems. ([4b0e8a58](https://github.com/fledge-framework/fledge/commit/4b0e8a58c63ef1cc974419c777e23d5a8fefa1e4))
 - **FEAT**(fledge_physics): yieldAfter — pass-through after sustained contact. ([5af431e0](https://github.com/fledge-framework/fledge/commit/5af431e06101b6f80350c8e23416c58eedc202bb))
 - **FEAT**(fledge_physics): opt-in dynamic-vs-dynamic blocking. ([e264f586](https://github.com/fledge-framework/fledge/commit/e264f586778836cd99b64aafdbdadb056455885f))
 - **FEAT**(fledge_physics): fixed-step integration + resolution. ([271b41de](https://github.com/fledge-framework/fledge/commit/271b41defa06e8e9f58218e39fed4c6ab3989720))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(examples): add new drifter game demo. ([c126a144](https://github.com/fledge-framework/fledge/commit/c126a144fe20402104b01a259d4ee36a00327d92))
 - **FEAT**(fledge_physics): extract collision engine into new package. ([cc31acc0](https://github.com/fledge-framework/fledge/commit/cc31acc0a02159fd39fa0dcdb9655d223c4c0027))

#### `fledge_render_2d` - `v0.6.0`

 - **REFACTOR**(fledge_render): combine core systems from fledge_render_flutter. ([4126c272](https://github.com/fledge-framework/fledge/commit/4126c272f2ddd3a198a285c5a80afdbea79aa126))
 - **FIX**(fledge_render_2d): canvas drawer supports mirrored sprites. ([fc2b3440](https://github.com/fledge-framework/fledge/commit/fc2b34408cf39ea7ff0420a6b7100ff9ba41cad0))
 - **FIX**(fledge_render_2d): Y-sort keeps working past y = 100 px. ([faa9fd04](https://github.com/fledge-framework/fledge/commit/faa9fd04fab36f3a2b61b74155d9223eaba802ce))
 - **FIX**(fledge_render_2d): sprite anchor formula no longer mirrored. ([dcd70d65](https://github.com/fledge-framework/fledge/commit/dcd70d65a88a2cc51aaf9a4b95e0fecfb15ff91f))
 - **FIX**(fledge_render_2d): atlas/tile frames no longer draw offset by source position. ([c786f3b2](https://github.com/fledge-framework/fledge/commit/c786f3b28483f558c18078eb4417eff40a00850e))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**(fledge_render_2d): improve culling. ([966e8657](https://github.com/fledge-framework/fledge/commit/966e86576f4f886ad4afcd24958e607188e222f6))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**(fledge_physics): prevent clipping during pathfinding. ([dac8ffaf](https://github.com/fledge-framework/fledge/commit/dac8ffaf3c8dd2815a626ae80694561823530a08))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_render_2d): expose systemName on transform / animation / transition systems. ([5813ff7a](https://github.com/fledge-framework/fledge/commit/5813ff7a34bba1623b5abdec394d8bcfa304e6d6))
 - **FEAT**(fledge_render_2d): pixel-snap the camera canvas offset when pixelPerfect. ([3137dc16](https://github.com/fledge-framework/fledge/commit/3137dc16178b2d2c35eb4aa9d6d08eae13ccdbe9))
 - **FEAT**: camera-aware widget render path. ([6b8ff1b7](https://github.com/fledge-framework/fledge/commit/6b8ff1b7f1eaf6a930a73d7a4c5a0c4e26f12385))
 - **FEAT**(fledge_render_2d): AtlasSprite gains an anchor field. ([d713ff50](https://github.com/fledge-framework/fledge/commit/d713ff5000a9673fc30b363d7833cf5a1a6be499))
 - **FEAT**(fledge_render_2d): render interpolation between fixed ticks. ([6179b2d5](https://github.com/fledge-framework/fledge/commit/6179b2d5d1392d5719448521f100bbac640b6b7a))
 - **FEAT**(fledge_render_2d): emit TransitionCompleted when a fade transition finishes. ([85d3f225](https://github.com/fledge-framework/fledge/commit/85d3f2250be1ff9b952a5ddf50c6db9eaf78a097))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_save): create fledge_save package. ([48a3a327](https://github.com/fledge-framework/fledge/commit/48a3a327b9c0950ec320d7f805cce19bf7a300f6))
 - **FEAT**(fledge_tiled): add CulledTilemapExtractor. ([8ad8e658](https://github.com/fledge-framework/fledge/commit/8ad8e65817ad8074f55929085fe6d8747da6e114))
 - **FEAT**(fledge_tiled): refactor TilemapSpawnConfig API. ([35b12d1e](https://github.com/fledge-framework/fledge/commit/35b12d1eaa72f7e703f6820b4e0f8d69452f509e))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

#### `fledge_save` - `v0.6.0`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_audio): upgrade to leverage soloud. ([13964f36](https://github.com/fledge-framework/fledge/commit/13964f36394d8c39981071d5f03d9d8c153ce4c4))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: adopt CalendarPlugin. ([815b8576](https://github.com/fledge-framework/fledge/commit/815b8576d960004c378f99d379a4d0949dbdf8ef))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_save): create fledge_save package. ([48a3a327](https://github.com/fledge-framework/fledge/commit/48a3a327b9c0950ec320d7f805cce19bf7a300f6))

#### `fledge_tiled` - `v0.6.0`

 - **REFACTOR**(fledge_tiled): depend on fledge_render_2d instead of the fledge_render shim. ([72becfe6](https://github.com/fledge-framework/fledge/commit/72becfe6bef448a30cf5a4d59bbd6fed651678a9))
 - **REFACTOR**(fledge_render): combine core systems from fledge_render_flutter. ([4126c272](https://github.com/fledge-framework/fledge/commit/4126c272f2ddd3a198a285c5a80afdbea79aa126))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**(fledge_render_2d): improve culling. ([966e8657](https://github.com/fledge-framework/fledge/commit/966e86576f4f886ad4afcd24958e607188e222f6))
 - **FEAT**(fledge_tiled): extract collision from tilesets. ([a5db2352](https://github.com/fledge-framework/fledge/commit/a5db2352f66ec5d5f1d61a8541dbda9b3ff9b1a2))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**(fledge_physics): weighted pathfinding and cost-aware path smoothing. ([42a8899d](https://github.com/fledge-framework/fledge/commit/42a8899d19b666779323c756e6e520b4c1d5e2c3))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_tiled): expose TilemapSpawnSystem.systemName. ([3b5ea9f9](https://github.com/fledge-framework/fledge/commit/3b5ea9f9c3e4adaf9f2694133b83b188a3b73aa1))
 - **FEAT**(fledge_tiled): emit ExtractedSprite so tiles draw through FledgeRenderView. ([76ad87f7](https://github.com/fledge-framework/fledge/commit/76ad87f7c9f3b5a8d1bb64bc9847931924227b44))
 - **FEAT**(fledge_tiled): read tilemaps from Assets<TilemapAsset>. ([eb0515f2](https://github.com/fledge-framework/fledge/commit/eb0515f27f746f536a4060683b178716b9d40b3c))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_tiled): add CulledTilemapExtractor. ([8ad8e658](https://github.com/fledge-framework/fledge/commit/8ad8e65817ad8074f55929085fe6d8747da6e114))
 - **FEAT**(fledge_tiled): add support for pathfinding. ([23ba2e0c](https://github.com/fledge-framework/fledge/commit/23ba2e0cad68aabb2bc8a7a0fab52c0af96acd58))
 - **FEAT**(fledge_tiled): enable class based tile sorting. ([291d9a12](https://github.com/fledge-framework/fledge/commit/291d9a12ed5d99912919497b024e7fdd286ae1ce))
 - **FEAT**(fledge_tiled): refactor TilemapSpawnConfig API. ([35b12d1e](https://github.com/fledge-framework/fledge/commit/35b12d1eaa72f7e703f6820b4e0f8d69452f509e))
 - **FEAT**(fledge_render): use layer enums rather than magic numbers. ([b7337885](https://github.com/fledge-framework/fledge/commit/b73378851a5fc04ea34893e6cd1690a6067b3a46))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

#### `fledge_tween` - `v0.6.0`

 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_ui` - `v0.6.0`

 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_ui): placement mode. ([7a378aef](https://github.com/fledge-framework/fledge/commit/7a378aeff4540bfc9b78f4755875ac02fbd153d0))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_window` - `v0.6.0`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**(fledge_core): performance enhancements. ([839f52da](https://github.com/fledge-framework/fledge/commit/839f52dacb8eab4c1c69d7610cafb52b3af7601f))
 - **FEAT**: make vsync checks asyncronous to prevent frame skips. ([a1f5cc97](https://github.com/fledge-framework/fledge/commit/a1f5cc97cca011e8f9be638bc4473eeb97858718))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_window): expose WindowInitSystem.systemName. ([1c1bd0c7](https://github.com/fledge-framework/fledge/commit/1c1bd0c71295a6208389ac2d45994978507755cb))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(examples): add new drifter game demo. ([c126a144](https://github.com/fledge-framework/fledge/commit/c126a144fe20402104b01a259d4ee36a00327d92))
 - **FEAT**(fledge_window): add error handling. ([affec7da](https://github.com/fledge-framework/fledge/commit/affec7dacc8dd5821d09adc6e96ebc2258a64f5f))
 - **FEAT**(fledge_net): create net package. ([dfed40d6](https://github.com/fledge-framework/fledge/commit/dfed40d6773ee9371bca5cf432372e265bdc0bb0))
 - **FEAT**(fledge_window): add close command on app. ([d30f616f](https://github.com/fledge-framework/fledge/commit/d30f616feda5b50af3217ea505815ceb8c360705))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))


## 2026-10-12

### Changes

---

Packages with breaking changes:

 - [`fledge_yarn` - `v0.5.0`](#fledge_yarn---v050)

Packages with other changes:

 - [`fledge_assets` - `v0.5.0`](#fledge_assets---v050)
 - [`fledge_audio` - `v0.5.0`](#fledge_audio---v050)
 - [`fledge_calendar` - `v0.5.0`](#fledge_calendar---v050)
 - [`fledge_camera_2d` - `v0.5.0`](#fledge_camera_2d---v050)
 - [`fledge_debug` - `v0.5.0`](#fledge_debug---v050)
 - [`fledge_ecs` - `v0.5.0`](#fledge_ecs---v050)
 - [`fledge_ecs_annotations` - `v0.5.0`](#fledge_ecs_annotations---v050)
 - [`fledge_ecs_generator` - `v0.5.0`](#fledge_ecs_generator---v050)
 - [`fledge_input` - `v0.5.0`](#fledge_input---v050)
 - [`fledge_lighting_2d` - `v0.5.0`](#fledge_lighting_2d---v050)
 - [`fledge_net` - `v0.5.0`](#fledge_net---v050)
 - [`fledge_particles` - `v0.5.0`](#fledge_particles---v050)
 - [`fledge_physics` - `v0.5.0`](#fledge_physics---v050)
 - [`fledge_render_2d` - `v0.5.0`](#fledge_render_2d---v050)
 - [`fledge_save` - `v0.5.0`](#fledge_save---v050)
 - [`fledge_tiled` - `v0.5.0`](#fledge_tiled---v050)
 - [`fledge_tween` - `v0.5.0`](#fledge_tween---v050)
 - [`fledge_ui` - `v0.5.0`](#fledge_ui---v050)
 - [`fledge_window` - `v0.5.0`](#fledge_window---v050)

---

#### `fledge_yarn` - `v0.5.0`

 - **FIX**(fledge_yarn): jump to a missing node no longer leaves the previous line up. ([33a6ac05](https://github.com/fledge-framework/fledge/commit/33a6ac054cab948839ec306e8a3363dd107e566d))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_yarn): pausing command callbacks. ([8c117ce1](https://github.com/fledge-framework/fledge/commit/8c117ce153f3908816d22c3240c98e75b5a3af2d))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_yarn): create fledge_yarn for yarnspinner. ([9bbee221](https://github.com/fledge-framework/fledge/commit/9bbee2213966a290074b265ed60e57198d1047c0))
 - **DOCS**(fledge_yarn): tag grammar. ([6a4895fb](https://github.com/fledge-framework/fledge/commit/6a4895fbe48578d06d35c1afe446ba93f0411966))
 - **BREAKING** **FEAT**(fledge_yarn): event-driven dialogue layer. ([3f4be34d](https://github.com/fledge-framework/fledge/commit/3f4be34d8104c2cc2a56030dfe7012421304900b))

#### `fledge_assets` - `v0.5.0`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_audio` - `v0.5.0`

 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**: bump lower bound of fledge_audio. ([1198dd84](https://github.com/fledge-framework/fledge/commit/1198dd8466d6d92b11ebc5b9127e6ce66c92edab))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_audio): expose systemName on AudioInitSystem and SpatialAudioSystem. ([d79dce3c](https://github.com/fledge-framework/fledge/commit/d79dce3c6c224120e5cf6b7b79454a681d6b5f14))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_tiled): refactor TilemapSpawnConfig API. ([35b12d1e](https://github.com/fledge-framework/fledge/commit/35b12d1eaa72f7e703f6820b4e0f8d69452f509e))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

#### `fledge_calendar` - `v0.5.0`

 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**(fledge_calendar): order CalendarSystem after wallTimeUpdate. ([f61ce1e6](https://github.com/fledge-framework/fledge/commit/f61ce1e69778a51f5f4ea3befe0e4b99076ee763))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: adopt CalendarPlugin. ([815b8576](https://github.com/fledge-framework/fledge/commit/815b8576d960004c378f99d379a4d0949dbdf8ef))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_camera_2d` - `v0.5.0`

 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**(fledge_camera_2d): CameraFollow.marker stays quiet until a target appears. ([d1894e64](https://github.com/fledge-framework/fledge/commit/d1894e645754d3a9418e273826b8d14a80e52c2f))
 - **FIX**(fledge_camera_2d): order ActiveCameraViewSystem after transform_propagate. ([42af6b8b](https://github.com/fledge-framework/fledge/commit/42af6b8baf01bcfc3f58d0c37392cc1912d7a4d1))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_camera_2d): expose CameraFollowSystem.systemName and ActiveCameraViewSystem.systemName. ([d42ccd1e](https://github.com/fledge-framework/fledge/commit/d42ccd1eb519d38eb71fc91e7787914cada05f75))
 - **FEAT**(fledge_render_2d): pixel-snap the camera canvas offset when pixelPerfect. ([3137dc16](https://github.com/fledge-framework/fledge/commit/3137dc16178b2d2c35eb4aa9d6d08eae13ccdbe9))
 - **FEAT**: camera-aware widget render path. ([6b8ff1b7](https://github.com/fledge-framework/fledge/commit/6b8ff1b7f1eaf6a930a73d7a4c5a0c4e26f12385))
 - **FEAT**(fledge_camera_2d): CameraFollow updates root camera GlobalTransform2D + marker target. ([4794cfc9](https://github.com/fledge-framework/fledge/commit/4794cfc90072f4ba2c1b05ba3881bb69d71ca3db))
 - **FEAT**(fledge_camera_2d): CameraFollowSystem — declare order + honour pixelPerfect. ([e7a77ef0](https://github.com/fledge-framework/fledge/commit/e7a77ef06b9f96d57dce359a2223212b37ea7f2d))
 - **FEAT**(fledge_render_2d): render interpolation between fixed ticks. ([6179b2d5](https://github.com/fledge-framework/fledge/commit/6179b2d5d1392d5719448521f100bbac640b6b7a))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_debug` - `v0.5.0`

 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**(fledge_debug): keep an existing DebugConfig instead of overwriting it. ([8c5b3725](https://github.com/fledge-framework/fledge/commit/8c5b3725bbfd84a86f4f0d87d6a77840ab12f242))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_debug): auto-refresh ScheduleOrderingReport on first tick. ([0e152b9e](https://github.com/fledge-framework/fledge/commit/0e152b9e6eaf00f9f30096d9f61c1f2c7a0c777a))
 - **FEAT**(fledge_debug): optional overlay and a standalone stats plugin. ([aef458b1](https://github.com/fledge-framework/fledge/commit/aef458b1ff7ceb251fbb46c7d9fbe244f43939f0))
 - **FEAT**: camera-aware widget render path. ([6b8ff1b7](https://github.com/fledge-framework/fledge/commit/6b8ff1b7f1eaf6a930a73d7a4c5a0c4e26f12385))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_ecs` - `v0.5.0`

 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**(fledge_ecs): explicit before/after overrides registration-order conflict edges. ([e698e92f](https://github.com/fledge-framework/fledge/commit/e698e92fd4bf396d60d5131f94ea3a0296b9f25e))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FIX**(fledge_input): fix timing issue for action resolution. ([62356b0d](https://github.com/fledge-framework/fledge/commit/62356b0d81db96018025579a544517bf85499de5))
 - **FIX**(fledge_ecs): create missing getters. ([e8f8ee3b](https://github.com/fledge-framework/fledge/commit/e8f8ee3ba27bf40d69599dda78ed27353f0cd7bb))
 - **FEAT**(fledge_ecs): add FixedTimestep.nudge for external clock sync. ([25e3cfe5](https://github.com/fledge-framework/fledge/commit/25e3cfe5b96a300e522013c9d58a1a2903305f8b))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_ecs): fan-out before/after when multiple systems share a name. ([664c4fd9](https://github.com/fledge-framework/fledge/commit/664c4fd9f8990ae17e2e1a3062c30a832ab24b9a))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(examples): add new drifter game demo. ([c126a144](https://github.com/fledge-framework/fledge/commit/c126a144fe20402104b01a259d4ee36a00327d92))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_save): create fledge_save package. ([48a3a327](https://github.com/fledge-framework/fledge/commit/48a3a327b9c0950ec320d7f805cce19bf7a300f6))
 - **FEAT**(fledge_ecs): add game checkpoint api. ([3b140dcc](https://github.com/fledge-framework/fledge/commit/3b140dccd5e52f9e6159e2059c161914cbafb6f7))
 - **FEAT**(fledge_physics): extract collision engine into new package. ([cc31acc0](https://github.com/fledge-framework/fledge/commit/cc31acc0a02159fd39fa0dcdb9655d223c4c0027))
 - **FEAT**(fledge_tiled): refactor TilemapSpawnConfig API. ([35b12d1e](https://github.com/fledge-framework/fledge/commit/35b12d1eaa72f7e703f6820b4e0f8d69452f509e))
 - **FEAT**(fledge_ecs): add advanced disposal functions. ([79479d10](https://github.com/fledge-framework/fledge/commit/79479d1027eb91954975c140c390f208a4f7de84))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))
 - **DOCS**(fledge_ecs): schedule_label comments reflect that App.tick drives fixed/extract/render. ([82292987](https://github.com/fledge-framework/fledge/commit/82292987556e9f327048a00c1a418c7f506b5b62))

#### `fledge_ecs_annotations` - `v0.5.0`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

#### `fledge_ecs_generator` - `v0.5.0`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): create net package. ([dfed40d6](https://github.com/fledge-framework/fledge/commit/dfed40d6773ee9371bca5cf432372e265bdc0bb0))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

#### `fledge_input` - `v0.5.0`

 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FIX**(fledge_input): persist input transition flags through the entire frame. ([f96f8ca2](https://github.com/fledge-framework/fledge/commit/f96f8ca2e5ae6f5cbf502d422014321d93ce4a1a))
 - **FIX**(fledge_input): fix timing issue for action resolution. ([62356b0d](https://github.com/fledge-framework/fledge/commit/62356b0d81db96018025579a544517bf85499de5))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(examples): add new drifter game demo. ([c126a144](https://github.com/fledge-framework/fledge/commit/c126a144fe20402104b01a259d4ee36a00327d92))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_net): create net package. ([dfed40d6](https://github.com/fledge-framework/fledge/commit/dfed40d6773ee9371bca5cf432372e265bdc0bb0))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

#### `fledge_lighting_2d` - `v0.5.0`

 - **FIX**(fledge_lighting_2d): camera-aware additive light pass fills the visible world viewport. ([23bae1ac](https://github.com/fledge-framework/fledge/commit/23bae1acc5358817a3a469ee8000f379e21e46bf))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_lighting_2d): optional AmbientLight.bounds clips the overSprites multiply. ([e6429852](https://github.com/fledge-framework/fledge/commit/e64298524b34d0fcdcb755570f262c67727e75c1))
 - **FEAT**: camera-aware widget render path. ([6b8ff1b7](https://github.com/fledge-framework/fledge/commit/6b8ff1b7f1eaf6a930a73d7a4c5a0c4e26f12385))
 - **FEAT**(fledge_lighting_2d): AmbientBlend.overSprites — ambient darkens sprites too. ([7d0c33db](https://github.com/fledge-framework/fledge/commit/7d0c33dbb8bb5bb6a89b4d73faecfa04d2780a07))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_net` - `v0.5.0`

 - **FIX**(fledge_net): latency fixes. ([c686b6ec](https://github.com/fledge-framework/fledge/commit/c686b6ec4727b4923f2e5a851718fb276bd1372c))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_ecs): add FixedTimestep.nudge for external clock sync. ([25e3cfe5](https://github.com/fledge-framework/fledge/commit/25e3cfe5b96a300e522013c9d58a1a2903305f8b))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_net): remediate documented limitations. ([203a78a6](https://github.com/fledge-framework/fledge/commit/203a78a6093897de435f9cf4528e3afcfab6073f))
 - **FEAT**(fledge_net): create net package. ([dfed40d6](https://github.com/fledge-framework/fledge/commit/dfed40d6773ee9371bca5cf432372e265bdc0bb0))

#### `fledge_particles` - `v0.5.0`

 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_physics` - `v0.5.0`

 - **FIX**(fledge_physics): yieldAfter counts blocked contact, not only overlap. ([f6bbb220](https://github.com/fledge-framework/fledge/commit/f6bbb220509bead9664c04cc4dd97051f0290eda))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_physics): add flutter dependency to package. ([c6608ee5](https://github.com/fledge-framework/fledge/commit/c6608ee5128672c4ec03963ca3b4abd8c507673f))
 - **FEAT**(fledge_physics): expose systemName on collision + velocity systems. ([4b0e8a58](https://github.com/fledge-framework/fledge/commit/4b0e8a58c63ef1cc974419c777e23d5a8fefa1e4))
 - **FEAT**(fledge_physics): yieldAfter — pass-through after sustained contact. ([5af431e0](https://github.com/fledge-framework/fledge/commit/5af431e06101b6f80350c8e23416c58eedc202bb))
 - **FEAT**(fledge_physics): opt-in dynamic-vs-dynamic blocking. ([e264f586](https://github.com/fledge-framework/fledge/commit/e264f586778836cd99b64aafdbdadb056455885f))
 - **FEAT**(fledge_physics): fixed-step integration + resolution. ([271b41de](https://github.com/fledge-framework/fledge/commit/271b41defa06e8e9f58218e39fed4c6ab3989720))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(examples): add new drifter game demo. ([c126a144](https://github.com/fledge-framework/fledge/commit/c126a144fe20402104b01a259d4ee36a00327d92))
 - **FEAT**(fledge_physics): extract collision engine into new package. ([cc31acc0](https://github.com/fledge-framework/fledge/commit/cc31acc0a02159fd39fa0dcdb9655d223c4c0027))

#### `fledge_render_2d` - `v0.5.0`

 - **REFACTOR**(fledge_render): combine core systems from fledge_render_flutter. ([4126c272](https://github.com/fledge-framework/fledge/commit/4126c272f2ddd3a198a285c5a80afdbea79aa126))
 - **FIX**(fledge_render_2d): canvas drawer supports mirrored sprites. ([fc2b3440](https://github.com/fledge-framework/fledge/commit/fc2b34408cf39ea7ff0420a6b7100ff9ba41cad0))
 - **FIX**(fledge_render_2d): Y-sort keeps working past y = 100 px. ([faa9fd04](https://github.com/fledge-framework/fledge/commit/faa9fd04fab36f3a2b61b74155d9223eaba802ce))
 - **FIX**(fledge_render_2d): sprite anchor formula no longer mirrored. ([dcd70d65](https://github.com/fledge-framework/fledge/commit/dcd70d65a88a2cc51aaf9a4b95e0fecfb15ff91f))
 - **FIX**(fledge_render_2d): atlas/tile frames no longer draw offset by source position. ([c786f3b2](https://github.com/fledge-framework/fledge/commit/c786f3b28483f558c18078eb4417eff40a00850e))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_render_2d): expose systemName on transform / animation / transition systems. ([5813ff7a](https://github.com/fledge-framework/fledge/commit/5813ff7a34bba1623b5abdec394d8bcfa304e6d6))
 - **FEAT**(fledge_render_2d): pixel-snap the camera canvas offset when pixelPerfect. ([3137dc16](https://github.com/fledge-framework/fledge/commit/3137dc16178b2d2c35eb4aa9d6d08eae13ccdbe9))
 - **FEAT**: camera-aware widget render path. ([6b8ff1b7](https://github.com/fledge-framework/fledge/commit/6b8ff1b7f1eaf6a930a73d7a4c5a0c4e26f12385))
 - **FEAT**(fledge_render_2d): AtlasSprite gains an anchor field. ([d713ff50](https://github.com/fledge-framework/fledge/commit/d713ff5000a9673fc30b363d7833cf5a1a6be499))
 - **FEAT**(fledge_render_2d): render interpolation between fixed ticks. ([6179b2d5](https://github.com/fledge-framework/fledge/commit/6179b2d5d1392d5719448521f100bbac640b6b7a))
 - **FEAT**(fledge_render_2d): emit TransitionCompleted when a fade transition finishes. ([85d3f225](https://github.com/fledge-framework/fledge/commit/85d3f2250be1ff9b952a5ddf50c6db9eaf78a097))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_save): create fledge_save package. ([48a3a327](https://github.com/fledge-framework/fledge/commit/48a3a327b9c0950ec320d7f805cce19bf7a300f6))
 - **FEAT**(fledge_tiled): add CulledTilemapExtractor. ([8ad8e658](https://github.com/fledge-framework/fledge/commit/8ad8e65817ad8074f55929085fe6d8747da6e114))
 - **FEAT**(fledge_tiled): refactor TilemapSpawnConfig API. ([35b12d1e](https://github.com/fledge-framework/fledge/commit/35b12d1eaa72f7e703f6820b4e0f8d69452f509e))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

#### `fledge_save` - `v0.5.0`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: adopt CalendarPlugin. ([815b8576](https://github.com/fledge-framework/fledge/commit/815b8576d960004c378f99d379a4d0949dbdf8ef))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_save): create fledge_save package. ([48a3a327](https://github.com/fledge-framework/fledge/commit/48a3a327b9c0950ec320d7f805cce19bf7a300f6))

#### `fledge_tiled` - `v0.5.0`

 - **REFACTOR**(fledge_tiled): depend on fledge_render_2d instead of the fledge_render shim. ([72becfe6](https://github.com/fledge-framework/fledge/commit/72becfe6bef448a30cf5a4d59bbd6fed651678a9))
 - **REFACTOR**(fledge_render): combine core systems from fledge_render_flutter. ([4126c272](https://github.com/fledge-framework/fledge/commit/4126c272f2ddd3a198a285c5a80afdbea79aa126))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_tiled): expose TilemapSpawnSystem.systemName. ([3b5ea9f9](https://github.com/fledge-framework/fledge/commit/3b5ea9f9c3e4adaf9f2694133b83b188a3b73aa1))
 - **FEAT**(fledge_tiled): emit ExtractedSprite so tiles draw through FledgeRenderView. ([76ad87f7](https://github.com/fledge-framework/fledge/commit/76ad87f7c9f3b5a8d1bb64bc9847931924227b44))
 - **FEAT**(fledge_tiled): read tilemaps from Assets<TilemapAsset>. ([eb0515f2](https://github.com/fledge-framework/fledge/commit/eb0515f27f746f536a4060683b178716b9d40b3c))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_tiled): add CulledTilemapExtractor. ([8ad8e658](https://github.com/fledge-framework/fledge/commit/8ad8e65817ad8074f55929085fe6d8747da6e114))
 - **FEAT**(fledge_tiled): add support for pathfinding. ([23ba2e0c](https://github.com/fledge-framework/fledge/commit/23ba2e0cad68aabb2bc8a7a0fab52c0af96acd58))
 - **FEAT**(fledge_tiled): enable class based tile sorting. ([291d9a12](https://github.com/fledge-framework/fledge/commit/291d9a12ed5d99912919497b024e7fdd286ae1ce))
 - **FEAT**(fledge_tiled): refactor TilemapSpawnConfig API. ([35b12d1e](https://github.com/fledge-framework/fledge/commit/35b12d1eaa72f7e703f6820b4e0f8d69452f509e))
 - **FEAT**(fledge_render): use layer enums rather than magic numbers. ([b7337885](https://github.com/fledge-framework/fledge/commit/b73378851a5fc04ea34893e6cd1690a6067b3a46))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

#### `fledge_tween` - `v0.5.0`

 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_ui` - `v0.5.0`

 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_ui): placement mode. ([7a378aef](https://github.com/fledge-framework/fledge/commit/7a378aeff4540bfc9b78f4755875ac02fbd153d0))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_window` - `v0.5.0`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_window): expose WindowInitSystem.systemName. ([1c1bd0c7](https://github.com/fledge-framework/fledge/commit/1c1bd0c71295a6208389ac2d45994978507755cb))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(examples): add new drifter game demo. ([c126a144](https://github.com/fledge-framework/fledge/commit/c126a144fe20402104b01a259d4ee36a00327d92))
 - **FEAT**(fledge_window): add error handling. ([affec7da](https://github.com/fledge-framework/fledge/commit/affec7dacc8dd5821d09adc6e96ebc2258a64f5f))
 - **FEAT**(fledge_net): create net package. ([dfed40d6](https://github.com/fledge-framework/fledge/commit/dfed40d6773ee9371bca5cf432372e265bdc0bb0))
 - **FEAT**(fledge_window): add close command on app. ([d30f616f](https://github.com/fledge-framework/fledge/commit/d30f616feda5b50af3217ea505815ceb8c360705))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))


## 2026-10-12

### Changes

---

Packages with breaking changes:

 - [`fledge_yarn` - `v0.4.0`](#fledge_yarn---v040)

Packages with other changes:

 - [`fledge_assets` - `v0.4.0`](#fledge_assets---v040)
 - [`fledge_audio` - `v0.4.0`](#fledge_audio---v040)
 - [`fledge_calendar` - `v0.4.0`](#fledge_calendar---v040)
 - [`fledge_camera_2d` - `v0.4.0`](#fledge_camera_2d---v040)
 - [`fledge_debug` - `v0.4.0`](#fledge_debug---v040)
 - [`fledge_ecs` - `v0.4.0`](#fledge_ecs---v040)
 - [`fledge_ecs_annotations` - `v0.4.0`](#fledge_ecs_annotations---v040)
 - [`fledge_ecs_generator` - `v0.4.0`](#fledge_ecs_generator---v040)
 - [`fledge_input` - `v0.4.0`](#fledge_input---v040)
 - [`fledge_lighting_2d` - `v0.4.0`](#fledge_lighting_2d---v040)
 - [`fledge_net` - `v0.4.0`](#fledge_net---v040)
 - [`fledge_particles` - `v0.4.0`](#fledge_particles---v040)
 - [`fledge_physics` - `v0.4.0`](#fledge_physics---v040)
 - [`fledge_render_2d` - `v0.4.0`](#fledge_render_2d---v040)
 - [`fledge_save` - `v0.4.0`](#fledge_save---v040)
 - [`fledge_tiled` - `v0.4.0`](#fledge_tiled---v040)
 - [`fledge_tween` - `v0.4.0`](#fledge_tween---v040)
 - [`fledge_ui` - `v0.4.0`](#fledge_ui---v040)
 - [`fledge_window` - `v0.4.0`](#fledge_window---v040)

---

#### `fledge_yarn` - `v0.4.0`

 - **FIX**(fledge_yarn): jump to a missing node no longer leaves the previous line up. ([33a6ac05](https://github.com/fledge-framework/fledge/commit/33a6ac054cab948839ec306e8a3363dd107e566d))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_yarn): pausing command callbacks. ([8c117ce1](https://github.com/fledge-framework/fledge/commit/8c117ce153f3908816d22c3240c98e75b5a3af2d))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_yarn): create fledge_yarn for yarnspinner. ([9bbee221](https://github.com/fledge-framework/fledge/commit/9bbee2213966a290074b265ed60e57198d1047c0))
 - **DOCS**(fledge_yarn): tag grammar. ([6a4895fb](https://github.com/fledge-framework/fledge/commit/6a4895fbe48578d06d35c1afe446ba93f0411966))
 - **BREAKING** **FEAT**(fledge_yarn): event-driven dialogue layer. ([3f4be34d](https://github.com/fledge-framework/fledge/commit/3f4be34d8104c2cc2a56030dfe7012421304900b))

#### `fledge_assets` - `v0.4.0`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_audio` - `v0.4.0`

 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**: bump lower bound of fledge_audio. ([1198dd84](https://github.com/fledge-framework/fledge/commit/1198dd8466d6d92b11ebc5b9127e6ce66c92edab))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_audio): expose systemName on AudioInitSystem and SpatialAudioSystem. ([d79dce3c](https://github.com/fledge-framework/fledge/commit/d79dce3c6c224120e5cf6b7b79454a681d6b5f14))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_tiled): refactor TilemapSpawnConfig API. ([35b12d1e](https://github.com/fledge-framework/fledge/commit/35b12d1eaa72f7e703f6820b4e0f8d69452f509e))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

#### `fledge_calendar` - `v0.4.0`

 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**(fledge_calendar): order CalendarSystem after wallTimeUpdate. ([f61ce1e6](https://github.com/fledge-framework/fledge/commit/f61ce1e69778a51f5f4ea3befe0e4b99076ee763))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: adopt CalendarPlugin. ([815b8576](https://github.com/fledge-framework/fledge/commit/815b8576d960004c378f99d379a4d0949dbdf8ef))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_camera_2d` - `v0.4.0`

 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**(fledge_camera_2d): CameraFollow.marker stays quiet until a target appears. ([d1894e64](https://github.com/fledge-framework/fledge/commit/d1894e645754d3a9418e273826b8d14a80e52c2f))
 - **FIX**(fledge_camera_2d): order ActiveCameraViewSystem after transform_propagate. ([42af6b8b](https://github.com/fledge-framework/fledge/commit/42af6b8baf01bcfc3f58d0c37392cc1912d7a4d1))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_camera_2d): expose CameraFollowSystem.systemName and ActiveCameraViewSystem.systemName. ([d42ccd1e](https://github.com/fledge-framework/fledge/commit/d42ccd1eb519d38eb71fc91e7787914cada05f75))
 - **FEAT**(fledge_render_2d): pixel-snap the camera canvas offset when pixelPerfect. ([3137dc16](https://github.com/fledge-framework/fledge/commit/3137dc16178b2d2c35eb4aa9d6d08eae13ccdbe9))
 - **FEAT**: camera-aware widget render path. ([6b8ff1b7](https://github.com/fledge-framework/fledge/commit/6b8ff1b7f1eaf6a930a73d7a4c5a0c4e26f12385))
 - **FEAT**(fledge_camera_2d): CameraFollow updates root camera GlobalTransform2D + marker target. ([4794cfc9](https://github.com/fledge-framework/fledge/commit/4794cfc90072f4ba2c1b05ba3881bb69d71ca3db))
 - **FEAT**(fledge_camera_2d): CameraFollowSystem — declare order + honour pixelPerfect. ([e7a77ef0](https://github.com/fledge-framework/fledge/commit/e7a77ef06b9f96d57dce359a2223212b37ea7f2d))
 - **FEAT**(fledge_render_2d): render interpolation between fixed ticks. ([6179b2d5](https://github.com/fledge-framework/fledge/commit/6179b2d5d1392d5719448521f100bbac640b6b7a))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_debug` - `v0.4.0`

 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**(fledge_debug): keep an existing DebugConfig instead of overwriting it. ([8c5b3725](https://github.com/fledge-framework/fledge/commit/8c5b3725bbfd84a86f4f0d87d6a77840ab12f242))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_debug): auto-refresh ScheduleOrderingReport on first tick. ([0e152b9e](https://github.com/fledge-framework/fledge/commit/0e152b9e6eaf00f9f30096d9f61c1f2c7a0c777a))
 - **FEAT**(fledge_debug): optional overlay and a standalone stats plugin. ([aef458b1](https://github.com/fledge-framework/fledge/commit/aef458b1ff7ceb251fbb46c7d9fbe244f43939f0))
 - **FEAT**: camera-aware widget render path. ([6b8ff1b7](https://github.com/fledge-framework/fledge/commit/6b8ff1b7f1eaf6a930a73d7a4c5a0c4e26f12385))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_ecs` - `v0.4.0`

 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**(fledge_ecs): explicit before/after overrides registration-order conflict edges. ([e698e92f](https://github.com/fledge-framework/fledge/commit/e698e92fd4bf396d60d5131f94ea3a0296b9f25e))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FIX**(fledge_input): fix timing issue for action resolution. ([62356b0d](https://github.com/fledge-framework/fledge/commit/62356b0d81db96018025579a544517bf85499de5))
 - **FIX**(fledge_ecs): create missing getters. ([e8f8ee3b](https://github.com/fledge-framework/fledge/commit/e8f8ee3ba27bf40d69599dda78ed27353f0cd7bb))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_ecs): fan-out before/after when multiple systems share a name. ([664c4fd9](https://github.com/fledge-framework/fledge/commit/664c4fd9f8990ae17e2e1a3062c30a832ab24b9a))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(examples): add new drifter game demo. ([c126a144](https://github.com/fledge-framework/fledge/commit/c126a144fe20402104b01a259d4ee36a00327d92))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_save): create fledge_save package. ([48a3a327](https://github.com/fledge-framework/fledge/commit/48a3a327b9c0950ec320d7f805cce19bf7a300f6))
 - **FEAT**(fledge_ecs): add game checkpoint api. ([3b140dcc](https://github.com/fledge-framework/fledge/commit/3b140dccd5e52f9e6159e2059c161914cbafb6f7))
 - **FEAT**(fledge_physics): extract collision engine into new package. ([cc31acc0](https://github.com/fledge-framework/fledge/commit/cc31acc0a02159fd39fa0dcdb9655d223c4c0027))
 - **FEAT**(fledge_tiled): refactor TilemapSpawnConfig API. ([35b12d1e](https://github.com/fledge-framework/fledge/commit/35b12d1eaa72f7e703f6820b4e0f8d69452f509e))
 - **FEAT**(fledge_ecs): add advanced disposal functions. ([79479d10](https://github.com/fledge-framework/fledge/commit/79479d1027eb91954975c140c390f208a4f7de84))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))
 - **DOCS**(fledge_ecs): schedule_label comments reflect that App.tick drives fixed/extract/render. ([82292987](https://github.com/fledge-framework/fledge/commit/82292987556e9f327048a00c1a418c7f506b5b62))

#### `fledge_ecs_annotations` - `v0.4.0`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

#### `fledge_ecs_generator` - `v0.4.0`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): create net package. ([dfed40d6](https://github.com/fledge-framework/fledge/commit/dfed40d6773ee9371bca5cf432372e265bdc0bb0))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

#### `fledge_input` - `v0.4.0`

 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FIX**(fledge_input): persist input transition flags through the entire frame. ([f96f8ca2](https://github.com/fledge-framework/fledge/commit/f96f8ca2e5ae6f5cbf502d422014321d93ce4a1a))
 - **FIX**(fledge_input): fix timing issue for action resolution. ([62356b0d](https://github.com/fledge-framework/fledge/commit/62356b0d81db96018025579a544517bf85499de5))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(examples): add new drifter game demo. ([c126a144](https://github.com/fledge-framework/fledge/commit/c126a144fe20402104b01a259d4ee36a00327d92))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_net): create net package. ([dfed40d6](https://github.com/fledge-framework/fledge/commit/dfed40d6773ee9371bca5cf432372e265bdc0bb0))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

#### `fledge_lighting_2d` - `v0.4.0`

 - **FIX**(fledge_lighting_2d): camera-aware additive light pass fills the visible world viewport. ([23bae1ac](https://github.com/fledge-framework/fledge/commit/23bae1acc5358817a3a469ee8000f379e21e46bf))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_lighting_2d): optional AmbientLight.bounds clips the overSprites multiply. ([e6429852](https://github.com/fledge-framework/fledge/commit/e64298524b34d0fcdcb755570f262c67727e75c1))
 - **FEAT**: camera-aware widget render path. ([6b8ff1b7](https://github.com/fledge-framework/fledge/commit/6b8ff1b7f1eaf6a930a73d7a4c5a0c4e26f12385))
 - **FEAT**(fledge_lighting_2d): AmbientBlend.overSprites — ambient darkens sprites too. ([7d0c33db](https://github.com/fledge-framework/fledge/commit/7d0c33dbb8bb5bb6a89b4d73faecfa04d2780a07))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_net` - `v0.4.0`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_net): remediate documented limitations. ([203a78a6](https://github.com/fledge-framework/fledge/commit/203a78a6093897de435f9cf4528e3afcfab6073f))
 - **FEAT**(fledge_net): create net package. ([dfed40d6](https://github.com/fledge-framework/fledge/commit/dfed40d6773ee9371bca5cf432372e265bdc0bb0))

#### `fledge_particles` - `v0.4.0`

 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_physics` - `v0.4.0`

 - **FIX**(fledge_physics): yieldAfter counts blocked contact, not only overlap. ([f6bbb220](https://github.com/fledge-framework/fledge/commit/f6bbb220509bead9664c04cc4dd97051f0290eda))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_physics): add flutter dependency to package. ([c6608ee5](https://github.com/fledge-framework/fledge/commit/c6608ee5128672c4ec03963ca3b4abd8c507673f))
 - **FEAT**(fledge_physics): expose systemName on collision + velocity systems. ([4b0e8a58](https://github.com/fledge-framework/fledge/commit/4b0e8a58c63ef1cc974419c777e23d5a8fefa1e4))
 - **FEAT**(fledge_physics): yieldAfter — pass-through after sustained contact. ([5af431e0](https://github.com/fledge-framework/fledge/commit/5af431e06101b6f80350c8e23416c58eedc202bb))
 - **FEAT**(fledge_physics): opt-in dynamic-vs-dynamic blocking. ([e264f586](https://github.com/fledge-framework/fledge/commit/e264f586778836cd99b64aafdbdadb056455885f))
 - **FEAT**(fledge_physics): fixed-step integration + resolution. ([271b41de](https://github.com/fledge-framework/fledge/commit/271b41defa06e8e9f58218e39fed4c6ab3989720))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(examples): add new drifter game demo. ([c126a144](https://github.com/fledge-framework/fledge/commit/c126a144fe20402104b01a259d4ee36a00327d92))
 - **FEAT**(fledge_physics): extract collision engine into new package. ([cc31acc0](https://github.com/fledge-framework/fledge/commit/cc31acc0a02159fd39fa0dcdb9655d223c4c0027))

#### `fledge_render_2d` - `v0.4.0`

 - **REFACTOR**(fledge_render): combine core systems from fledge_render_flutter. ([4126c272](https://github.com/fledge-framework/fledge/commit/4126c272f2ddd3a198a285c5a80afdbea79aa126))
 - **FIX**(fledge_render_2d): canvas drawer supports mirrored sprites. ([fc2b3440](https://github.com/fledge-framework/fledge/commit/fc2b34408cf39ea7ff0420a6b7100ff9ba41cad0))
 - **FIX**(fledge_render_2d): Y-sort keeps working past y = 100 px. ([faa9fd04](https://github.com/fledge-framework/fledge/commit/faa9fd04fab36f3a2b61b74155d9223eaba802ce))
 - **FIX**(fledge_render_2d): sprite anchor formula no longer mirrored. ([dcd70d65](https://github.com/fledge-framework/fledge/commit/dcd70d65a88a2cc51aaf9a4b95e0fecfb15ff91f))
 - **FIX**(fledge_render_2d): atlas/tile frames no longer draw offset by source position. ([c786f3b2](https://github.com/fledge-framework/fledge/commit/c786f3b28483f558c18078eb4417eff40a00850e))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_render_2d): expose systemName on transform / animation / transition systems. ([5813ff7a](https://github.com/fledge-framework/fledge/commit/5813ff7a34bba1623b5abdec394d8bcfa304e6d6))
 - **FEAT**(fledge_render_2d): pixel-snap the camera canvas offset when pixelPerfect. ([3137dc16](https://github.com/fledge-framework/fledge/commit/3137dc16178b2d2c35eb4aa9d6d08eae13ccdbe9))
 - **FEAT**: camera-aware widget render path. ([6b8ff1b7](https://github.com/fledge-framework/fledge/commit/6b8ff1b7f1eaf6a930a73d7a4c5a0c4e26f12385))
 - **FEAT**(fledge_render_2d): AtlasSprite gains an anchor field. ([d713ff50](https://github.com/fledge-framework/fledge/commit/d713ff5000a9673fc30b363d7833cf5a1a6be499))
 - **FEAT**(fledge_render_2d): render interpolation between fixed ticks. ([6179b2d5](https://github.com/fledge-framework/fledge/commit/6179b2d5d1392d5719448521f100bbac640b6b7a))
 - **FEAT**(fledge_render_2d): emit TransitionCompleted when a fade transition finishes. ([85d3f225](https://github.com/fledge-framework/fledge/commit/85d3f2250be1ff9b952a5ddf50c6db9eaf78a097))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_save): create fledge_save package. ([48a3a327](https://github.com/fledge-framework/fledge/commit/48a3a327b9c0950ec320d7f805cce19bf7a300f6))
 - **FEAT**(fledge_tiled): add CulledTilemapExtractor. ([8ad8e658](https://github.com/fledge-framework/fledge/commit/8ad8e65817ad8074f55929085fe6d8747da6e114))
 - **FEAT**(fledge_tiled): refactor TilemapSpawnConfig API. ([35b12d1e](https://github.com/fledge-framework/fledge/commit/35b12d1eaa72f7e703f6820b4e0f8d69452f509e))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

#### `fledge_save` - `v0.4.0`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: adopt CalendarPlugin. ([815b8576](https://github.com/fledge-framework/fledge/commit/815b8576d960004c378f99d379a4d0949dbdf8ef))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_save): create fledge_save package. ([48a3a327](https://github.com/fledge-framework/fledge/commit/48a3a327b9c0950ec320d7f805cce19bf7a300f6))

#### `fledge_tiled` - `v0.4.0`

 - **REFACTOR**(fledge_tiled): depend on fledge_render_2d instead of the fledge_render shim. ([72becfe6](https://github.com/fledge-framework/fledge/commit/72becfe6bef448a30cf5a4d59bbd6fed651678a9))
 - **REFACTOR**(fledge_render): combine core systems from fledge_render_flutter. ([4126c272](https://github.com/fledge-framework/fledge/commit/4126c272f2ddd3a198a285c5a80afdbea79aa126))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_tiled): expose TilemapSpawnSystem.systemName. ([3b5ea9f9](https://github.com/fledge-framework/fledge/commit/3b5ea9f9c3e4adaf9f2694133b83b188a3b73aa1))
 - **FEAT**(fledge_tiled): emit ExtractedSprite so tiles draw through FledgeRenderView. ([76ad87f7](https://github.com/fledge-framework/fledge/commit/76ad87f7c9f3b5a8d1bb64bc9847931924227b44))
 - **FEAT**(fledge_tiled): read tilemaps from Assets<TilemapAsset>. ([eb0515f2](https://github.com/fledge-framework/fledge/commit/eb0515f27f746f536a4060683b178716b9d40b3c))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_tiled): add CulledTilemapExtractor. ([8ad8e658](https://github.com/fledge-framework/fledge/commit/8ad8e65817ad8074f55929085fe6d8747da6e114))
 - **FEAT**(fledge_tiled): add support for pathfinding. ([23ba2e0c](https://github.com/fledge-framework/fledge/commit/23ba2e0cad68aabb2bc8a7a0fab52c0af96acd58))
 - **FEAT**(fledge_tiled): enable class based tile sorting. ([291d9a12](https://github.com/fledge-framework/fledge/commit/291d9a12ed5d99912919497b024e7fdd286ae1ce))
 - **FEAT**(fledge_tiled): refactor TilemapSpawnConfig API. ([35b12d1e](https://github.com/fledge-framework/fledge/commit/35b12d1eaa72f7e703f6820b4e0f8d69452f509e))
 - **FEAT**(fledge_render): use layer enums rather than magic numbers. ([b7337885](https://github.com/fledge-framework/fledge/commit/b73378851a5fc04ea34893e6cd1690a6067b3a46))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

#### `fledge_tween` - `v0.4.0`

 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_ui` - `v0.4.0`

 - **FIX**: resolve incompatible apis. ([70d581c9](https://github.com/fledge-framework/fledge/commit/70d581c96c54d59d8ffc94ce791b8bb241194296))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_ui): placement mode. ([7a378aef](https://github.com/fledge-framework/fledge/commit/7a378aeff4540bfc9b78f4755875ac02fbd153d0))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_window` - `v0.4.0`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**: update render graph. ([1a2aa4f7](https://github.com/fledge-framework/fledge/commit/1a2aa4f762ac933ac1aa9d8ebce431e8016908a8))
 - **FEAT**(fledge_window): expose WindowInitSystem.systemName. ([1c1bd0c7](https://github.com/fledge-framework/fledge/commit/1c1bd0c71295a6208389ac2d45994978507755cb))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(examples): add new drifter game demo. ([c126a144](https://github.com/fledge-framework/fledge/commit/c126a144fe20402104b01a259d4ee36a00327d92))
 - **FEAT**(fledge_window): add error handling. ([affec7da](https://github.com/fledge-framework/fledge/commit/affec7dacc8dd5821d09adc6e96ebc2258a64f5f))
 - **FEAT**(fledge_net): create net package. ([dfed40d6](https://github.com/fledge-framework/fledge/commit/dfed40d6773ee9371bca5cf432372e265bdc0bb0))
 - **FEAT**(fledge_window): add close command on app. ([d30f616f](https://github.com/fledge-framework/fledge/commit/d30f616feda5b50af3217ea505815ceb8c360705))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))


## 2026-09-22

### Changes

---

Packages with breaking changes:

 - [`fledge_yarn` - `v0.3.1`](#fledge_yarn---v031)

Packages with other changes:

 - [`fledge_assets` - `v0.3.1`](#fledge_assets---v031)
 - [`fledge_audio` - `v0.3.1`](#fledge_audio---v031)
 - [`fledge_calendar` - `v0.3.1`](#fledge_calendar---v031)
 - [`fledge_camera_2d` - `v0.3.1`](#fledge_camera_2d---v031)
 - [`fledge_debug` - `v0.3.1`](#fledge_debug---v031)
 - [`fledge_ecs_annotations` - `v0.3.1`](#fledge_ecs_annotations---v031)
 - [`fledge_ecs_generator` - `v0.3.1`](#fledge_ecs_generator---v031)
 - [`fledge_ecs` - `v0.3.1`](#fledge_ecs---v031)
 - [`fledge_input` - `v0.3.1`](#fledge_input---v031)
 - [`fledge_lighting_2d` - `v0.3.1`](#fledge_lighting_2d---v031)
 - [`fledge_net` - `v0.3.1`](#fledge_net---v031)
 - [`fledge_particles` - `v0.3.1`](#fledge_particles---v031)
 - [`fledge_physics` - `v0.3.1`](#fledge_physics---v031)
 - [`fledge_render_2d` - `v0.3.1`](#fledge_render_2d---v031)
 - [`fledge_save` - `v0.3.1`](#fledge_save---v031)
 - [`fledge_tiled` - `v0.3.1`](#fledge_tiled---v031)
 - [`fledge_tween` - `v0.3.1`](#fledge_tween---v031)
 - [`fledge_ui` - `v0.3.1`](#fledge_ui---v031)
 - [`fledge_window` - `v0.3.1`](#fledge_window---v031)

---

#### `fledge_yarn` - `v0.3.1`

 - **FIX**(fledge_yarn): jump to a missing node no longer leaves the previous line up. ([33a6ac05](https://github.com/fledge-framework/fledge/commit/33a6ac054cab948839ec306e8a3363dd107e566d))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_yarn): pausing command callbacks. ([8c117ce1](https://github.com/fledge-framework/fledge/commit/8c117ce153f3908816d22c3240c98e75b5a3af2d))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_yarn): create fledge_yarn for yarnspinner. ([9bbee221](https://github.com/fledge-framework/fledge/commit/9bbee2213966a290074b265ed60e57198d1047c0))
 - **DOCS**(fledge_yarn): tag grammar. ([6a4895fb](https://github.com/fledge-framework/fledge/commit/6a4895fbe48578d06d35c1afe446ba93f0411966))
 - **BREAKING** **FEAT**(fledge_yarn): event-driven dialogue layer. ([3f4be34d](https://github.com/fledge-framework/fledge/commit/3f4be34d8104c2cc2a56030dfe7012421304900b))

#### `fledge_assets` - `v0.3.1`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_audio` - `v0.3.1`

 - **FIX**: bump lower bound of fledge_audio. ([1198dd84](https://github.com/fledge-framework/fledge/commit/1198dd8466d6d92b11ebc5b9127e6ce66c92edab))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**(fledge_audio): expose systemName on AudioInitSystem and SpatialAudioSystem. ([d79dce3c](https://github.com/fledge-framework/fledge/commit/d79dce3c6c224120e5cf6b7b79454a681d6b5f14))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_tiled): refactor TilemapSpawnConfig API. ([35b12d1e](https://github.com/fledge-framework/fledge/commit/35b12d1eaa72f7e703f6820b4e0f8d69452f509e))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

#### `fledge_calendar` - `v0.3.1`

 - **FIX**(fledge_calendar): order CalendarSystem after wallTimeUpdate. ([f61ce1e6](https://github.com/fledge-framework/fledge/commit/f61ce1e69778a51f5f4ea3befe0e4b99076ee763))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: adopt CalendarPlugin. ([815b8576](https://github.com/fledge-framework/fledge/commit/815b8576d960004c378f99d379a4d0949dbdf8ef))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_camera_2d` - `v0.3.1`

 - **FIX**(fledge_camera_2d): CameraFollow.marker stays quiet until a target appears. ([d1894e64](https://github.com/fledge-framework/fledge/commit/d1894e645754d3a9418e273826b8d14a80e52c2f))
 - **FIX**(fledge_camera_2d): order ActiveCameraViewSystem after transform_propagate. ([42af6b8b](https://github.com/fledge-framework/fledge/commit/42af6b8baf01bcfc3f58d0c37392cc1912d7a4d1))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_camera_2d): expose CameraFollowSystem.systemName and ActiveCameraViewSystem.systemName. ([d42ccd1e](https://github.com/fledge-framework/fledge/commit/d42ccd1eb519d38eb71fc91e7787914cada05f75))
 - **FEAT**(fledge_render_2d): pixel-snap the camera canvas offset when pixelPerfect. ([3137dc16](https://github.com/fledge-framework/fledge/commit/3137dc16178b2d2c35eb4aa9d6d08eae13ccdbe9))
 - **FEAT**: camera-aware widget render path. ([6b8ff1b7](https://github.com/fledge-framework/fledge/commit/6b8ff1b7f1eaf6a930a73d7a4c5a0c4e26f12385))
 - **FEAT**(fledge_camera_2d): CameraFollow updates root camera GlobalTransform2D + marker target. ([4794cfc9](https://github.com/fledge-framework/fledge/commit/4794cfc90072f4ba2c1b05ba3881bb69d71ca3db))
 - **FEAT**(fledge_camera_2d): CameraFollowSystem — declare order + honour pixelPerfect. ([e7a77ef0](https://github.com/fledge-framework/fledge/commit/e7a77ef06b9f96d57dce359a2223212b37ea7f2d))
 - **FEAT**(fledge_render_2d): render interpolation between fixed ticks. ([6179b2d5](https://github.com/fledge-framework/fledge/commit/6179b2d5d1392d5719448521f100bbac640b6b7a))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_debug` - `v0.3.1`

 - **FIX**(fledge_debug): keep an existing DebugConfig instead of overwriting it. ([8c5b3725](https://github.com/fledge-framework/fledge/commit/8c5b3725bbfd84a86f4f0d87d6a77840ab12f242))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_debug): auto-refresh ScheduleOrderingReport on first tick. ([0e152b9e](https://github.com/fledge-framework/fledge/commit/0e152b9e6eaf00f9f30096d9f61c1f2c7a0c777a))
 - **FEAT**(fledge_debug): optional overlay and a standalone stats plugin. ([aef458b1](https://github.com/fledge-framework/fledge/commit/aef458b1ff7ceb251fbb46c7d9fbe244f43939f0))
 - **FEAT**: camera-aware widget render path. ([6b8ff1b7](https://github.com/fledge-framework/fledge/commit/6b8ff1b7f1eaf6a930a73d7a4c5a0c4e26f12385))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_ecs_annotations` - `v0.3.1`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

#### `fledge_ecs_generator` - `v0.3.1`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): create net package. ([dfed40d6](https://github.com/fledge-framework/fledge/commit/dfed40d6773ee9371bca5cf432372e265bdc0bb0))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

#### `fledge_ecs` - `v0.3.1`

 - **FIX**(fledge_ecs): explicit before/after overrides registration-order conflict edges. ([e698e92f](https://github.com/fledge-framework/fledge/commit/e698e92fd4bf396d60d5131f94ea3a0296b9f25e))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FIX**(fledge_input): fix timing issue for action resolution. ([62356b0d](https://github.com/fledge-framework/fledge/commit/62356b0d81db96018025579a544517bf85499de5))
 - **FIX**(fledge_ecs): create missing getters. ([e8f8ee3b](https://github.com/fledge-framework/fledge/commit/e8f8ee3ba27bf40d69599dda78ed27353f0cd7bb))
 - **FEAT**(fledge_ecs): fan-out before/after when multiple systems share a name. ([664c4fd9](https://github.com/fledge-framework/fledge/commit/664c4fd9f8990ae17e2e1a3062c30a832ab24b9a))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(examples): add new drifter game demo. ([c126a144](https://github.com/fledge-framework/fledge/commit/c126a144fe20402104b01a259d4ee36a00327d92))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_save): create fledge_save package. ([48a3a327](https://github.com/fledge-framework/fledge/commit/48a3a327b9c0950ec320d7f805cce19bf7a300f6))
 - **FEAT**(fledge_ecs): add game checkpoint api. ([3b140dcc](https://github.com/fledge-framework/fledge/commit/3b140dccd5e52f9e6159e2059c161914cbafb6f7))
 - **FEAT**(fledge_physics): extract collision engine into new package. ([cc31acc0](https://github.com/fledge-framework/fledge/commit/cc31acc0a02159fd39fa0dcdb9655d223c4c0027))
 - **FEAT**(fledge_tiled): refactor TilemapSpawnConfig API. ([35b12d1e](https://github.com/fledge-framework/fledge/commit/35b12d1eaa72f7e703f6820b4e0f8d69452f509e))
 - **FEAT**(fledge_ecs): add advanced disposal functions. ([79479d10](https://github.com/fledge-framework/fledge/commit/79479d1027eb91954975c140c390f208a4f7de84))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))
 - **DOCS**(fledge_ecs): schedule_label comments reflect that App.tick drives fixed/extract/render. ([82292987](https://github.com/fledge-framework/fledge/commit/82292987556e9f327048a00c1a418c7f506b5b62))

#### `fledge_input` - `v0.3.1`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FIX**(fledge_input): persist input transition flags through the entire frame. ([f96f8ca2](https://github.com/fledge-framework/fledge/commit/f96f8ca2e5ae6f5cbf502d422014321d93ce4a1a))
 - **FIX**(fledge_input): fix timing issue for action resolution. ([62356b0d](https://github.com/fledge-framework/fledge/commit/62356b0d81db96018025579a544517bf85499de5))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(examples): add new drifter game demo. ([c126a144](https://github.com/fledge-framework/fledge/commit/c126a144fe20402104b01a259d4ee36a00327d92))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_net): create net package. ([dfed40d6](https://github.com/fledge-framework/fledge/commit/dfed40d6773ee9371bca5cf432372e265bdc0bb0))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

#### `fledge_lighting_2d` - `v0.3.1`

 - **FIX**(fledge_lighting_2d): camera-aware additive light pass fills the visible world viewport. ([23bae1ac](https://github.com/fledge-framework/fledge/commit/23bae1acc5358817a3a469ee8000f379e21e46bf))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_lighting_2d): optional AmbientLight.bounds clips the overSprites multiply. ([e6429852](https://github.com/fledge-framework/fledge/commit/e64298524b34d0fcdcb755570f262c67727e75c1))
 - **FEAT**: camera-aware widget render path. ([6b8ff1b7](https://github.com/fledge-framework/fledge/commit/6b8ff1b7f1eaf6a930a73d7a4c5a0c4e26f12385))
 - **FEAT**(fledge_lighting_2d): AmbientBlend.overSprites — ambient darkens sprites too. ([7d0c33db](https://github.com/fledge-framework/fledge/commit/7d0c33dbb8bb5bb6a89b4d73faecfa04d2780a07))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_net` - `v0.3.1`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_net): remediate documented limitations. ([203a78a6](https://github.com/fledge-framework/fledge/commit/203a78a6093897de435f9cf4528e3afcfab6073f))
 - **FEAT**(fledge_net): create net package. ([dfed40d6](https://github.com/fledge-framework/fledge/commit/dfed40d6773ee9371bca5cf432372e265bdc0bb0))

#### `fledge_particles` - `v0.3.1`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_physics` - `v0.3.1`

 - **FIX**(fledge_physics): yieldAfter counts blocked contact, not only overlap. ([f6bbb220](https://github.com/fledge-framework/fledge/commit/f6bbb220509bead9664c04cc4dd97051f0290eda))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_physics): add flutter dependency to package. ([c6608ee5](https://github.com/fledge-framework/fledge/commit/c6608ee5128672c4ec03963ca3b4abd8c507673f))
 - **FEAT**(fledge_physics): expose systemName on collision + velocity systems. ([4b0e8a58](https://github.com/fledge-framework/fledge/commit/4b0e8a58c63ef1cc974419c777e23d5a8fefa1e4))
 - **FEAT**(fledge_physics): yieldAfter — pass-through after sustained contact. ([5af431e0](https://github.com/fledge-framework/fledge/commit/5af431e06101b6f80350c8e23416c58eedc202bb))
 - **FEAT**(fledge_physics): opt-in dynamic-vs-dynamic blocking. ([e264f586](https://github.com/fledge-framework/fledge/commit/e264f586778836cd99b64aafdbdadb056455885f))
 - **FEAT**(fledge_physics): fixed-step integration + resolution. ([271b41de](https://github.com/fledge-framework/fledge/commit/271b41defa06e8e9f58218e39fed4c6ab3989720))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(examples): add new drifter game demo. ([c126a144](https://github.com/fledge-framework/fledge/commit/c126a144fe20402104b01a259d4ee36a00327d92))
 - **FEAT**(fledge_physics): extract collision engine into new package. ([cc31acc0](https://github.com/fledge-framework/fledge/commit/cc31acc0a02159fd39fa0dcdb9655d223c4c0027))

#### `fledge_render_2d` - `v0.3.1`

 - **REFACTOR**(fledge_render): combine core systems from fledge_render_flutter. ([4126c272](https://github.com/fledge-framework/fledge/commit/4126c272f2ddd3a198a285c5a80afdbea79aa126))
 - **FIX**(fledge_render_2d): canvas drawer supports mirrored sprites. ([fc2b3440](https://github.com/fledge-framework/fledge/commit/fc2b34408cf39ea7ff0420a6b7100ff9ba41cad0))
 - **FIX**(fledge_render_2d): Y-sort keeps working past y = 100 px. ([faa9fd04](https://github.com/fledge-framework/fledge/commit/faa9fd04fab36f3a2b61b74155d9223eaba802ce))
 - **FIX**(fledge_render_2d): sprite anchor formula no longer mirrored. ([dcd70d65](https://github.com/fledge-framework/fledge/commit/dcd70d65a88a2cc51aaf9a4b95e0fecfb15ff91f))
 - **FIX**(fledge_render_2d): atlas/tile frames no longer draw offset by source position. ([c786f3b2](https://github.com/fledge-framework/fledge/commit/c786f3b28483f558c18078eb4417eff40a00850e))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**(fledge_render_2d): expose systemName on transform / animation / transition systems. ([5813ff7a](https://github.com/fledge-framework/fledge/commit/5813ff7a34bba1623b5abdec394d8bcfa304e6d6))
 - **FEAT**(fledge_render_2d): pixel-snap the camera canvas offset when pixelPerfect. ([3137dc16](https://github.com/fledge-framework/fledge/commit/3137dc16178b2d2c35eb4aa9d6d08eae13ccdbe9))
 - **FEAT**: camera-aware widget render path. ([6b8ff1b7](https://github.com/fledge-framework/fledge/commit/6b8ff1b7f1eaf6a930a73d7a4c5a0c4e26f12385))
 - **FEAT**(fledge_render_2d): AtlasSprite gains an anchor field. ([d713ff50](https://github.com/fledge-framework/fledge/commit/d713ff5000a9673fc30b363d7833cf5a1a6be499))
 - **FEAT**(fledge_render_2d): render interpolation between fixed ticks. ([6179b2d5](https://github.com/fledge-framework/fledge/commit/6179b2d5d1392d5719448521f100bbac640b6b7a))
 - **FEAT**(fledge_render_2d): emit TransitionCompleted when a fade transition finishes. ([85d3f225](https://github.com/fledge-framework/fledge/commit/85d3f2250be1ff9b952a5ddf50c6db9eaf78a097))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_save): create fledge_save package. ([48a3a327](https://github.com/fledge-framework/fledge/commit/48a3a327b9c0950ec320d7f805cce19bf7a300f6))
 - **FEAT**(fledge_tiled): add CulledTilemapExtractor. ([8ad8e658](https://github.com/fledge-framework/fledge/commit/8ad8e65817ad8074f55929085fe6d8747da6e114))
 - **FEAT**(fledge_tiled): refactor TilemapSpawnConfig API. ([35b12d1e](https://github.com/fledge-framework/fledge/commit/35b12d1eaa72f7e703f6820b4e0f8d69452f509e))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

#### `fledge_save` - `v0.3.1`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: adopt CalendarPlugin. ([815b8576](https://github.com/fledge-framework/fledge/commit/815b8576d960004c378f99d379a4d0949dbdf8ef))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_save): create fledge_save package. ([48a3a327](https://github.com/fledge-framework/fledge/commit/48a3a327b9c0950ec320d7f805cce19bf7a300f6))

#### `fledge_tiled` - `v0.3.1`

 - **REFACTOR**(fledge_tiled): depend on fledge_render_2d instead of the fledge_render shim. ([72becfe6](https://github.com/fledge-framework/fledge/commit/72becfe6bef448a30cf5a4d59bbd6fed651678a9))
 - **REFACTOR**(fledge_render): combine core systems from fledge_render_flutter. ([4126c272](https://github.com/fledge-framework/fledge/commit/4126c272f2ddd3a198a285c5a80afdbea79aa126))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**(fledge_tiled): expose TilemapSpawnSystem.systemName. ([3b5ea9f9](https://github.com/fledge-framework/fledge/commit/3b5ea9f9c3e4adaf9f2694133b83b188a3b73aa1))
 - **FEAT**(fledge_tiled): emit ExtractedSprite so tiles draw through FledgeRenderView. ([76ad87f7](https://github.com/fledge-framework/fledge/commit/76ad87f7c9f3b5a8d1bb64bc9847931924227b44))
 - **FEAT**(fledge_tiled): read tilemaps from Assets<TilemapAsset>. ([eb0515f2](https://github.com/fledge-framework/fledge/commit/eb0515f27f746f536a4060683b178716b9d40b3c))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_tiled): add CulledTilemapExtractor. ([8ad8e658](https://github.com/fledge-framework/fledge/commit/8ad8e65817ad8074f55929085fe6d8747da6e114))
 - **FEAT**(fledge_tiled): add support for pathfinding. ([23ba2e0c](https://github.com/fledge-framework/fledge/commit/23ba2e0cad68aabb2bc8a7a0fab52c0af96acd58))
 - **FEAT**(fledge_tiled): enable class based tile sorting. ([291d9a12](https://github.com/fledge-framework/fledge/commit/291d9a12ed5d99912919497b024e7fdd286ae1ce))
 - **FEAT**(fledge_tiled): refactor TilemapSpawnConfig API. ([35b12d1e](https://github.com/fledge-framework/fledge/commit/35b12d1eaa72f7e703f6820b4e0f8d69452f509e))
 - **FEAT**(fledge_render): use layer enums rather than magic numbers. ([b7337885](https://github.com/fledge-framework/fledge/commit/b73378851a5fc04ea34893e6cd1690a6067b3a46))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

#### `fledge_tween` - `v0.3.1`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_ui` - `v0.3.1`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_ui): placement mode. ([7a378aef](https://github.com/fledge-framework/fledge/commit/7a378aeff4540bfc9b78f4755875ac02fbd153d0))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_window` - `v0.3.1`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**(fledge_window): expose WindowInitSystem.systemName. ([1c1bd0c7](https://github.com/fledge-framework/fledge/commit/1c1bd0c71295a6208389ac2d45994978507755cb))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(examples): add new drifter game demo. ([c126a144](https://github.com/fledge-framework/fledge/commit/c126a144fe20402104b01a259d4ee36a00327d92))
 - **FEAT**(fledge_window): add error handling. ([affec7da](https://github.com/fledge-framework/fledge/commit/affec7dacc8dd5821d09adc6e96ebc2258a64f5f))
 - **FEAT**(fledge_net): create net package. ([dfed40d6](https://github.com/fledge-framework/fledge/commit/dfed40d6773ee9371bca5cf432372e265bdc0bb0))
 - **FEAT**(fledge_window): add close command on app. ([d30f616f](https://github.com/fledge-framework/fledge/commit/d30f616feda5b50af3217ea505815ceb8c360705))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))


## 2026-09-22

### Changes

---

Packages with breaking changes:

 - [`fledge_yarn` - `v0.3.0`](#fledge_yarn---v030)

Packages with other changes:

 - [`fledge_assets` - `v0.3.0`](#fledge_assets---v030)
 - [`fledge_audio` - `v0.3.0`](#fledge_audio---v030)
 - [`fledge_calendar` - `v0.3.0`](#fledge_calendar---v030)
 - [`fledge_camera_2d` - `v0.3.0`](#fledge_camera_2d---v030)
 - [`fledge_debug` - `v0.3.0`](#fledge_debug---v030)
 - [`fledge_ecs_annotations` - `v0.3.0`](#fledge_ecs_annotations---v030)
 - [`fledge_ecs_generator` - `v0.3.0`](#fledge_ecs_generator---v030)
 - [`fledge_ecs` - `v0.3.0`](#fledge_ecs---v030)
 - [`fledge_input` - `v0.3.0`](#fledge_input---v030)
 - [`fledge_lighting_2d` - `v0.3.0`](#fledge_lighting_2d---v030)
 - [`fledge_net` - `v0.3.0`](#fledge_net---v030)
 - [`fledge_particles` - `v0.3.0`](#fledge_particles---v030)
 - [`fledge_physics` - `v0.3.0`](#fledge_physics---v030)
 - [`fledge_render_2d` - `v0.3.0`](#fledge_render_2d---v030)
 - [`fledge_save` - `v0.3.0`](#fledge_save---v030)
 - [`fledge_tiled` - `v0.3.0`](#fledge_tiled---v030)
 - [`fledge_tween` - `v0.3.0`](#fledge_tween---v030)
 - [`fledge_ui` - `v0.3.0`](#fledge_ui---v030)
 - [`fledge_window` - `v0.3.0`](#fledge_window---v030)

---

#### `fledge_yarn` - `v0.3.0`

 - **FIX**(fledge_yarn): jump to a missing node no longer leaves the previous line up. ([33a6ac05](https://github.com/fledge-framework/fledge/commit/33a6ac054cab948839ec306e8a3363dd107e566d))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_yarn): pausing command callbacks. ([8c117ce1](https://github.com/fledge-framework/fledge/commit/8c117ce153f3908816d22c3240c98e75b5a3af2d))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_yarn): create fledge_yarn for yarnspinner. ([9bbee221](https://github.com/fledge-framework/fledge/commit/9bbee2213966a290074b265ed60e57198d1047c0))
 - **DOCS**(fledge_yarn): tag grammar. ([6a4895fb](https://github.com/fledge-framework/fledge/commit/6a4895fbe48578d06d35c1afe446ba93f0411966))
 - **BREAKING** **FEAT**(fledge_yarn): event-driven dialogue layer. ([093c026d](https://github.com/fledge-framework/fledge/commit/093c026df4120e9cd7f1a9da173db4baababcb85))

#### `fledge_assets` - `v0.3.0`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_audio` - `v0.3.0`

 - **FIX**: bump lower bound of fledge_audio. ([1198dd84](https://github.com/fledge-framework/fledge/commit/1198dd8466d6d92b11ebc5b9127e6ce66c92edab))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_tiled): refactor TilemapSpawnConfig API. ([35b12d1e](https://github.com/fledge-framework/fledge/commit/35b12d1eaa72f7e703f6820b4e0f8d69452f509e))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

#### `fledge_calendar` - `v0.3.0`

 - **FIX**(fledge_calendar): order CalendarSystem after wallTimeUpdate. ([f61ce1e6](https://github.com/fledge-framework/fledge/commit/f61ce1e69778a51f5f4ea3befe0e4b99076ee763))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: adopt CalendarPlugin. ([815b8576](https://github.com/fledge-framework/fledge/commit/815b8576d960004c378f99d379a4d0949dbdf8ef))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_camera_2d` - `v0.3.0`

 - **FIX**(fledge_camera_2d): CameraFollow.marker stays quiet until a target appears. ([d1894e64](https://github.com/fledge-framework/fledge/commit/d1894e645754d3a9418e273826b8d14a80e52c2f))
 - **FIX**(fledge_camera_2d): order ActiveCameraViewSystem after transform_propagate. ([42af6b8b](https://github.com/fledge-framework/fledge/commit/42af6b8baf01bcfc3f58d0c37392cc1912d7a4d1))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_render_2d): pixel-snap the camera canvas offset when pixelPerfect. ([3137dc16](https://github.com/fledge-framework/fledge/commit/3137dc16178b2d2c35eb4aa9d6d08eae13ccdbe9))
 - **FEAT**: camera-aware widget render path. ([6b8ff1b7](https://github.com/fledge-framework/fledge/commit/6b8ff1b7f1eaf6a930a73d7a4c5a0c4e26f12385))
 - **FEAT**(fledge_camera_2d): CameraFollow updates root camera GlobalTransform2D + marker target. ([4794cfc9](https://github.com/fledge-framework/fledge/commit/4794cfc90072f4ba2c1b05ba3881bb69d71ca3db))
 - **FEAT**(fledge_camera_2d): CameraFollowSystem — declare order + honour pixelPerfect. ([e7a77ef0](https://github.com/fledge-framework/fledge/commit/e7a77ef06b9f96d57dce359a2223212b37ea7f2d))
 - **FEAT**(fledge_render_2d): render interpolation between fixed ticks. ([6179b2d5](https://github.com/fledge-framework/fledge/commit/6179b2d5d1392d5719448521f100bbac640b6b7a))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_debug` - `v0.3.0`

 - **FIX**(fledge_debug): keep an existing DebugConfig instead of overwriting it. ([8c5b3725](https://github.com/fledge-framework/fledge/commit/8c5b3725bbfd84a86f4f0d87d6a77840ab12f242))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_debug): optional overlay and a standalone stats plugin. ([aef458b1](https://github.com/fledge-framework/fledge/commit/aef458b1ff7ceb251fbb46c7d9fbe244f43939f0))
 - **FEAT**: camera-aware widget render path. ([6b8ff1b7](https://github.com/fledge-framework/fledge/commit/6b8ff1b7f1eaf6a930a73d7a4c5a0c4e26f12385))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_ecs_annotations` - `v0.3.0`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

#### `fledge_ecs_generator` - `v0.3.0`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): create net package. ([dfed40d6](https://github.com/fledge-framework/fledge/commit/dfed40d6773ee9371bca5cf432372e265bdc0bb0))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

#### `fledge_ecs` - `v0.3.0`

 - **FIX**(fledge_ecs): explicit before/after overrides registration-order conflict edges. ([e698e92f](https://github.com/fledge-framework/fledge/commit/e698e92fd4bf396d60d5131f94ea3a0296b9f25e))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FIX**(fledge_input): fix timing issue for action resolution. ([62356b0d](https://github.com/fledge-framework/fledge/commit/62356b0d81db96018025579a544517bf85499de5))
 - **FIX**(fledge_ecs): create missing getters. ([e8f8ee3b](https://github.com/fledge-framework/fledge/commit/e8f8ee3ba27bf40d69599dda78ed27353f0cd7bb))
 - **FEAT**(fledge_ecs): fan-out before/after when multiple systems share a name. ([664c4fd9](https://github.com/fledge-framework/fledge/commit/664c4fd9f8990ae17e2e1a3062c30a832ab24b9a))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(examples): add new drifter game demo. ([c126a144](https://github.com/fledge-framework/fledge/commit/c126a144fe20402104b01a259d4ee36a00327d92))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_save): create fledge_save package. ([48a3a327](https://github.com/fledge-framework/fledge/commit/48a3a327b9c0950ec320d7f805cce19bf7a300f6))
 - **FEAT**(fledge_ecs): add game checkpoint api. ([3b140dcc](https://github.com/fledge-framework/fledge/commit/3b140dccd5e52f9e6159e2059c161914cbafb6f7))
 - **FEAT**(fledge_physics): extract collision engine into new package. ([cc31acc0](https://github.com/fledge-framework/fledge/commit/cc31acc0a02159fd39fa0dcdb9655d223c4c0027))
 - **FEAT**(fledge_tiled): refactor TilemapSpawnConfig API. ([35b12d1e](https://github.com/fledge-framework/fledge/commit/35b12d1eaa72f7e703f6820b4e0f8d69452f509e))
 - **FEAT**(fledge_ecs): add advanced disposal functions. ([79479d10](https://github.com/fledge-framework/fledge/commit/79479d1027eb91954975c140c390f208a4f7de84))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))
 - **DOCS**(fledge_ecs): schedule_label comments reflect that App.tick drives fixed/extract/render. ([82292987](https://github.com/fledge-framework/fledge/commit/82292987556e9f327048a00c1a418c7f506b5b62))

#### `fledge_input` - `v0.3.0`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FIX**(fledge_input): persist input transition flags through the entire frame. ([f96f8ca2](https://github.com/fledge-framework/fledge/commit/f96f8ca2e5ae6f5cbf502d422014321d93ce4a1a))
 - **FIX**(fledge_input): fix timing issue for action resolution. ([62356b0d](https://github.com/fledge-framework/fledge/commit/62356b0d81db96018025579a544517bf85499de5))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(examples): add new drifter game demo. ([c126a144](https://github.com/fledge-framework/fledge/commit/c126a144fe20402104b01a259d4ee36a00327d92))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_net): create net package. ([dfed40d6](https://github.com/fledge-framework/fledge/commit/dfed40d6773ee9371bca5cf432372e265bdc0bb0))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

#### `fledge_lighting_2d` - `v0.3.0`

 - **FIX**(fledge_lighting_2d): camera-aware additive light pass fills the visible world viewport. ([23bae1ac](https://github.com/fledge-framework/fledge/commit/23bae1acc5358817a3a469ee8000f379e21e46bf))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_lighting_2d): optional AmbientLight.bounds clips the overSprites multiply. ([e6429852](https://github.com/fledge-framework/fledge/commit/e64298524b34d0fcdcb755570f262c67727e75c1))
 - **FEAT**: camera-aware widget render path. ([6b8ff1b7](https://github.com/fledge-framework/fledge/commit/6b8ff1b7f1eaf6a930a73d7a4c5a0c4e26f12385))
 - **FEAT**(fledge_lighting_2d): AmbientBlend.overSprites — ambient darkens sprites too. ([7d0c33db](https://github.com/fledge-framework/fledge/commit/7d0c33dbb8bb5bb6a89b4d73faecfa04d2780a07))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_net` - `v0.3.0`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_net): remediate documented limitations. ([203a78a6](https://github.com/fledge-framework/fledge/commit/203a78a6093897de435f9cf4528e3afcfab6073f))
 - **FEAT**(fledge_net): create net package. ([dfed40d6](https://github.com/fledge-framework/fledge/commit/dfed40d6773ee9371bca5cf432372e265bdc0bb0))

#### `fledge_particles` - `v0.3.0`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_physics` - `v0.3.0`

 - **FIX**(fledge_physics): yieldAfter counts blocked contact, not only overlap. ([f6bbb220](https://github.com/fledge-framework/fledge/commit/f6bbb220509bead9664c04cc4dd97051f0290eda))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_physics): add flutter dependency to package. ([c6608ee5](https://github.com/fledge-framework/fledge/commit/c6608ee5128672c4ec03963ca3b4abd8c507673f))
 - **FEAT**(fledge_physics): yieldAfter — pass-through after sustained contact. ([5af431e0](https://github.com/fledge-framework/fledge/commit/5af431e06101b6f80350c8e23416c58eedc202bb))
 - **FEAT**(fledge_physics): opt-in dynamic-vs-dynamic blocking. ([e264f586](https://github.com/fledge-framework/fledge/commit/e264f586778836cd99b64aafdbdadb056455885f))
 - **FEAT**(fledge_physics): fixed-step integration + resolution. ([271b41de](https://github.com/fledge-framework/fledge/commit/271b41defa06e8e9f58218e39fed4c6ab3989720))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(examples): add new drifter game demo. ([c126a144](https://github.com/fledge-framework/fledge/commit/c126a144fe20402104b01a259d4ee36a00327d92))
 - **FEAT**(fledge_physics): extract collision engine into new package. ([cc31acc0](https://github.com/fledge-framework/fledge/commit/cc31acc0a02159fd39fa0dcdb9655d223c4c0027))

#### `fledge_render_2d` - `v0.3.0`

 - **REFACTOR**(fledge_render): combine core systems from fledge_render_flutter. ([4126c272](https://github.com/fledge-framework/fledge/commit/4126c272f2ddd3a198a285c5a80afdbea79aa126))
 - **FIX**(fledge_render_2d): canvas drawer supports mirrored sprites. ([fc2b3440](https://github.com/fledge-framework/fledge/commit/fc2b34408cf39ea7ff0420a6b7100ff9ba41cad0))
 - **FIX**(fledge_render_2d): Y-sort keeps working past y = 100 px. ([faa9fd04](https://github.com/fledge-framework/fledge/commit/faa9fd04fab36f3a2b61b74155d9223eaba802ce))
 - **FIX**(fledge_render_2d): sprite anchor formula no longer mirrored. ([dcd70d65](https://github.com/fledge-framework/fledge/commit/dcd70d65a88a2cc51aaf9a4b95e0fecfb15ff91f))
 - **FIX**(fledge_render_2d): atlas/tile frames no longer draw offset by source position. ([c786f3b2](https://github.com/fledge-framework/fledge/commit/c786f3b28483f558c18078eb4417eff40a00850e))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**(fledge_render_2d): pixel-snap the camera canvas offset when pixelPerfect. ([3137dc16](https://github.com/fledge-framework/fledge/commit/3137dc16178b2d2c35eb4aa9d6d08eae13ccdbe9))
 - **FEAT**: camera-aware widget render path. ([6b8ff1b7](https://github.com/fledge-framework/fledge/commit/6b8ff1b7f1eaf6a930a73d7a4c5a0c4e26f12385))
 - **FEAT**(fledge_render_2d): AtlasSprite gains an anchor field. ([d713ff50](https://github.com/fledge-framework/fledge/commit/d713ff5000a9673fc30b363d7833cf5a1a6be499))
 - **FEAT**(fledge_render_2d): render interpolation between fixed ticks. ([6179b2d5](https://github.com/fledge-framework/fledge/commit/6179b2d5d1392d5719448521f100bbac640b6b7a))
 - **FEAT**(fledge_render_2d): emit TransitionCompleted when a fade transition finishes. ([85d3f225](https://github.com/fledge-framework/fledge/commit/85d3f2250be1ff9b952a5ddf50c6db9eaf78a097))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_save): create fledge_save package. ([48a3a327](https://github.com/fledge-framework/fledge/commit/48a3a327b9c0950ec320d7f805cce19bf7a300f6))
 - **FEAT**(fledge_tiled): add CulledTilemapExtractor. ([8ad8e658](https://github.com/fledge-framework/fledge/commit/8ad8e65817ad8074f55929085fe6d8747da6e114))
 - **FEAT**(fledge_tiled): refactor TilemapSpawnConfig API. ([35b12d1e](https://github.com/fledge-framework/fledge/commit/35b12d1eaa72f7e703f6820b4e0f8d69452f509e))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

#### `fledge_save` - `v0.3.0`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: adopt CalendarPlugin. ([815b8576](https://github.com/fledge-framework/fledge/commit/815b8576d960004c378f99d379a4d0949dbdf8ef))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_save): create fledge_save package. ([48a3a327](https://github.com/fledge-framework/fledge/commit/48a3a327b9c0950ec320d7f805cce19bf7a300f6))

#### `fledge_tiled` - `v0.3.0`

 - **REFACTOR**(fledge_tiled): depend on fledge_render_2d instead of the fledge_render shim. ([72becfe6](https://github.com/fledge-framework/fledge/commit/72becfe6bef448a30cf5a4d59bbd6fed651678a9))
 - **REFACTOR**(fledge_render): combine core systems from fledge_render_flutter. ([4126c272](https://github.com/fledge-framework/fledge/commit/4126c272f2ddd3a198a285c5a80afdbea79aa126))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**(fledge_tiled): emit ExtractedSprite so tiles draw through FledgeRenderView. ([76ad87f7](https://github.com/fledge-framework/fledge/commit/76ad87f7c9f3b5a8d1bb64bc9847931924227b44))
 - **FEAT**(fledge_tiled): read tilemaps from Assets<TilemapAsset>. ([eb0515f2](https://github.com/fledge-framework/fledge/commit/eb0515f27f746f536a4060683b178716b9d40b3c))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_tiled): add CulledTilemapExtractor. ([8ad8e658](https://github.com/fledge-framework/fledge/commit/8ad8e65817ad8074f55929085fe6d8747da6e114))
 - **FEAT**(fledge_tiled): add support for pathfinding. ([23ba2e0c](https://github.com/fledge-framework/fledge/commit/23ba2e0cad68aabb2bc8a7a0fab52c0af96acd58))
 - **FEAT**(fledge_tiled): enable class based tile sorting. ([291d9a12](https://github.com/fledge-framework/fledge/commit/291d9a12ed5d99912919497b024e7fdd286ae1ce))
 - **FEAT**(fledge_tiled): refactor TilemapSpawnConfig API. ([35b12d1e](https://github.com/fledge-framework/fledge/commit/35b12d1eaa72f7e703f6820b4e0f8d69452f509e))
 - **FEAT**(fledge_render): use layer enums rather than magic numbers. ([b7337885](https://github.com/fledge-framework/fledge/commit/b73378851a5fc04ea34893e6cd1690a6067b3a46))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

#### `fledge_tween` - `v0.3.0`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_ui` - `v0.3.0`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_ui): placement mode. ([8316d6de](https://github.com/fledge-framework/fledge/commit/8316d6decd15d9d98b4250aba965e29c2458a25b))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

#### `fledge_window` - `v0.3.0`

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(examples): add new drifter game demo. ([c126a144](https://github.com/fledge-framework/fledge/commit/c126a144fe20402104b01a259d4ee36a00327d92))
 - **FEAT**(fledge_window): add error handling. ([affec7da](https://github.com/fledge-framework/fledge/commit/affec7dacc8dd5821d09adc6e96ebc2258a64f5f))
 - **FEAT**(fledge_net): create net package. ([dfed40d6](https://github.com/fledge-framework/fledge/commit/dfed40d6773ee9371bca5cf432372e265bdc0bb0))
 - **FEAT**(fledge_window): add close command on app. ([d30f616f](https://github.com/fledge-framework/fledge/commit/d30f616feda5b50af3217ea505815ceb8c360705))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

# Changelog

## [0.2.2] - 2026-09-21



## [0.2.0] - 2026-09-21

## [0.2.1] - 2026-09-21

### Bug Fixes

- Bump versions to stable
- Bump lower bound of fledge_audio
- Correct CI workflow

### Features

- V0.2 engine restructure — 2D/2.5D desktop game engine
- Add additional examples
- Upgrade tiled version

### Miscellaneous

- Update docs

### Ci

- Make workflow idempotent
- Fix workflow
- Make pana advisory
- Add manual publish script

### Lint

- Resolve formatting issues



## [0.2.1] - 2026-09-21

## [0.1.14] - 2026-04-14

### Features

- **fledge_net:** Add network packet encryption
- **fledge_window:** Add error handling
- **examples:** Add new drifter game demo

### Miscellaneous

- Update dependency definitions



## [0.1.14] - 2026-04-14

## [0.1.14] - 2026-04-14

### Features

- **fledge_net:** Add network packet encryption
- **fledge_window:** Add error handling
- **examples:** Add new drifter game demo

### Miscellaneous

- Update dependency definitions



## [0.1.13] - 2026-04-14

## [0.1.13] - 2026-04-14

### Features

- **fledge_net:** Remediate documented limitations

### Miscellaneous

- Add missing files for fledge_net



## [0.1.12] - 2026-04-14

## [0.1.12] - 2026-04-14

### Features

- **fledge_net:** Create net package

### Miscellaneous

- Use fledge input handling in docs
- Resolve analysis issues
- Update github workflow for new package



## [0.1.11] - 2026-01-21

## [0.1.11] - 2026-01-20

### Miscellaneous

- Update docs
- **docs:** Update getting started documentation



## [0.1.10] - 2026-01-06

## [0.1.10] - 2026-01-06

### Features

- **fledge_save:** Create fledge_save package

### Miscellaneous

- Bump versions
- Bump versions



## [0.1.9] - 2026-01-06

## [0.1.9] - 2026-01-06

### Features

- **fledge_tiled:** Add CulledTilemapExtractor



## [0.1.8] - 2026-01-06

## [0.1.8] - 2026-01-06

### Features

- **fledge_tiled:** Add support for pathfinding
- **fledge_yarn:** Create fledge_yarn for yarnspinner

### Miscellaneous

- **lint:** Format all files



## [0.1.7] - 2026-01-05

## [0.1.7] - 2026-01-05

### Features

- **fledge_tiled:** Enable class based tile sorting

### Miscellaneous

- Bump dependencies



## [0.1.6] - 2026-01-05

## [0.1.6] - 2026-01-05

### Bug Fixes

- **fledge_physics:** Add flutter dependency to package
- **fledge_render_flutter:** Clean up deprecated api files

### Features

- **fledge_ecs:** Add game checkpoint api
- **fledge_render:** Add plugin to auto register extractors

### Miscellaneous

- **readme:** Add documentation for fledge_physics

### Refactoring

- **fledge_render:** Combine core systems from fledge_render_flutter



## [0.1.5] - 2026-01-04

## [0.1.5] - 2026-01-04

### Miscellaneous

- **fledge_physics:** Provide docs for remaining public apis



## [0.1.4] - 2026-01-04

## [0.1.4] - 2026-01-04

### Bug Fixes

- **docs:** Allow all docs text to be selectable

### Ci

- **github:** Add publish step for fledge_physics
- **github:** Add analyze step for fledge_physics



## [0.1.3] - 2026-01-04

## [0.1.3] - 2026-01-04

### Bug Fixes

- **fledge_render_2d:** Fix null safety error on private field

### Features

- **docs:** Setup spa config for docs app
- **fledge_tiled:** Refactor TilemapSpawnConfig API
- **fledge_physics:** Extract collision engine into new package.

### Miscellaneous

- **lint:** Resolve const identifier issues



## [0.1.2] - 2026-01-03

## [0.1.2] - 2026-01-03

### Bug Fixes

- **fledge_input:** Persist input transition flags through the entire frame
- Update dependencies to latest stable versions
- **fledge:** Update dependencies, upgrade melos to v7

### Features

- **fledge_render:** Use layer enums rather than magic numbers

### Miscellaneous

- **license:** Remove whitespace from license files
- **docs:** Bump version
- **docs:** Correct license text
- **docs:** Bump version
- Add contribution information
- Update license text
- Bump versions

### Ci

- **github:** Use melos for path resolution for docs
- **github:** Add firebase experimental flag
- **github:** Create changelogs for all packages on release




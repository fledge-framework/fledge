# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

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




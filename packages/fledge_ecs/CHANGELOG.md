## 0.7.2

> Note: This release has breaking changes.

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

## 0.7.1

> Note: This release has breaking changes.

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

## 0.7.0

> Note: This release has breaking changes.

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

## 0.6.0

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

## 0.5.0

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

## 0.4.0

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

## 0.3.1

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

## 0.3.0

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

# Changelog

## [0.2.2] - 2026-09-21



## [0.2.1] - 2026-09-20

### Changed

- SDK floor bumped to Dart `>=3.11.0` (was 3.6). Matches the workspace-wide floor required by `analyzer` 13.x+ and `flutter_soloud` 4.x+.


## [0.2.0] - 2026-09-20

### Changed

- Scheduler rewritten around named schedule graph (`Schedules` + `Scheduler`); `stage:` argument on `addSystem` renamed to `schedule:`.
- `App.tick()` restructured to drive extract + render schedules on top of the main schedule.
- Query iterators snapshot archetype membership at iter start, fixing a silent-drop bug when systems spawned/despawned matching entities mid-iteration.

### Added

- `FixedTimestep` resource and fixed-timestep dispatch chain (`Schedules.fixedUpdate`).
- `Query1..4<T>` / `QueryMut1..4<T>` marker types; reads/writes are now inferred from the marker in generator output.
- `WallTime` / `WallTimePlugin` for real-time clocks.

### Deprecated

- `Time` / `TimePlugin` — use `WallTime` / `WallTimePlugin`.


## [0.1.14] - 2026-04-14

## [0.1.13] - 2026-04-14



## [0.1.12] - 2026-04-14



## [0.1.11] - 2026-01-21

## [0.1.10] - 2026-01-06

## [0.1.10] - 2026-01-06

### Features

- **fledge_save:** Create fledge_save package

### Miscellaneous

- Bump versions
- Bump versions



## [0.1.9] - 2026-01-06



## [0.1.8] - 2026-01-06



## [0.1.7] - 2026-01-05

## [0.1.7] - 2026-01-05

### Miscellaneous

- Bump dependencies



## [0.1.6] - 2026-01-05

## [0.1.5] - 2026-01-04



## [0.1.4] - 2026-01-04



## [0.1.3] - 2026-01-04

## [0.1.3] - 2026-01-04

### Bug Fixes

- **fledge_render_2d:** Fix null safety error on private field

### Features

- **fledge_tiled:** Refactor TilemapSpawnConfig API
- **fledge_physics:** Extract collision engine into new package.

### Miscellaneous

- **lint:** Resolve const identifier issues



## [0.1.2] - 2026-01-03

## [0.1.1] - 2025-01-03

### Added

- Session checkpoint API for managing session vs game-level state:
  - `App.markSessionCheckpoint()` - Mark current plugins as session-level
  - `App.resetToSessionCheckpoint()` - Reset to session state, cleanup game plugins
- `World.resetGameState()` - Clear entities, archetypes, and events while preserving resources
- `Schedule.clear()` - Remove all systems from all stages
- `SystemStage.clear()` - Remove all systems from a stage
- `World.archetypeCount` - Get total number of archetypes
- `World.resourceCount` - Get total number of resourcse

## [0.1.0] - 2025-01-02

### Added

- Initial release of fledge_ecs
- Entity and Component system with typed queries
- World management for entities and resources
- System scheduling with stages and ordering
- Resource management for global state
- Event system for inter-system communication
- Plugin architecture for modular game features
- Query system: `query`, `query2`, `query3`, `query4` for multi-component queries
- Time plugin with delta time tracking
- Entity commands: spawn, despawn, insert, remove

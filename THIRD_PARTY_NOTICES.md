# Third-party notices

`Saymote (遥控说)` is adapted from and builds upon the following open-source
projects and specifications:

- [VincentKingHsu/vRemoter](https://github.com/VincentKingHsu/vRemoter),
  distributed under the MIT License (direct upstream application architecture,
  CoreAudio routing, key remapping, and packaging scripts).
- [fanxeon/mi-ao](https://github.com/fanxeon/mi-ao), distributed under the MIT
  License, Copyright (c) 2026 FanXeon@Poemcoder with Codex (ATVV protocol and
  IMA/DVI ADPCM decoder in `Sources/Saymote/ATVV/`).

Its ATVV protocol and IMA/DVI ADPCM implementation were further informed by:

- [b0o/ATVVoice](https://github.com/b0o/ATVVoice), MIT License,
  Copyright (c) 2026 Maddison Cohodas.
- [Google Voice over BLE specification v1.0](https://wangefan.github.io/linux_kernel_driver/resources/Google_Voice_over_BLE_spec_v1.0.pdf).

`vRemoteDriver.driver` is a modified build of
[ExistentialAudio/BlackHole](https://github.com/ExistentialAudio/BlackHole)
0.4.1 and remains licensed under **GNU GPL v3**. The reproducible patch script
[`Driver/build-driver.sh`](Driver/build-driver.sh) documents every modification.
BlackHole's original `LICENSE` (GNU GPL v3) and `VERSION` (`0.4.1`) are preserved
inside the generated driver bundle.

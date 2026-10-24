# Pixel font resource

Bellkeep uses the unmodified **Fusion Pixel 12px Monospaced / Simplified Chinese** OTF from TakWolf's fixed **2026.10.16** release. This is an independently licensed open-source pixel font. No font from Undertale or any other commercial game was copied, and no system font is installed or used as a silent fallback.

## Source and license

- Project: https://github.com/TakWolf/fusion-pixel-font
- Fixed release: https://github.com/TakWolf/fusion-pixel-font/releases/tag/2026.10.16
- Official downloaded archive: https://github.com/TakWolf/fusion-pixel-font/releases/download/2026.10.16/fusion-pixel-font-12px-monospaced-otf-v2026.10.16.zip
- Archive SHA-256: `42082847da7973b03d666bf6e47d3bd40d5a973e8d0f8ad286d321e6602c916d`
- Selected archive entry / committed font: `assets/fonts/fusion-pixel-12px-monospaced-zh_hans.otf` (5,013,296 bytes)
- OTF SHA-256: `c557a18bf3540a318a0dee16ca5eec5370f0455d0e050f68cc09a667d94a5ca6`
- **Font license: SIL Open Font License 1.1**, retained in full at `assets/fonts/LICENSE-OFL`. Source: https://raw.githubusercontent.com/TakWolf/fusion-pixel-font/master/LICENSE-OFL
- Component notices supplied inside the same release are retained under `assets/fonts/licenses/`: Ark Pixel, Cubic 11 and Galmuri.

The source font and component licenses retain their original authorship and terms; the project's MIT license does not replace the font's OFL. The OTF bytes have not been modified. Only one font flavor was extracted. The zip remains in the ignored local source cache, outside shipped assets; no downloaded scripts were run.

## Runtime contract

`preload("res://presentation/pixel_font.gd").create()` returns a configured `FontFile`, or null with an error if the font resource has not been imported. Godot's ResourceLoader is used so normal imported-resource export includes the font. Do not replace this with a host-specific font path.

Use **12px** for compact HUD/body text and **24px** for doubled headings, with integer Control positions and `CanvasItem.TEXTURE_FILTER_NEAREST`. Other positive multiples of 12 are possible; fractional Control scaling, 16px font sizes, outlines that swallow one-pixel stems and dynamic font stretching should be avoided. Layout/wrapping and CanvasItem filtering belong to HUD logic, not to the font helper.

The helper explicitly disables system fallback, additional fallback fonts, antialiasing, mipmaps, MSDF, hinting, auto-hinting and subpixel positioning. Oversampling is fixed at 1.0. The source is a dynamic OTF authored on a 12px grid, so FontFile.fixed_size remains zero; Godot documents fixed_size as a bitmap-font setting. A missing character must be reported and resolved with a compatible pixel asset rather than replaced invisibly by a smooth system font.

Official API references checked for Godot 4.7:

- FontFile: https://docs.godotengine.org/en/4.7/classes/class_fontfile.html
- TextServer enum behavior: https://docs.godotengine.org/en/4.7/classes/class_textserver.html
- Dynamic font import settings: https://docs.godotengine.org/en/stable/classes/class_resourceimporterdynamicfont.html

## Validation

After importing the project, run `--headless --path . --script res://tools/font_glyph_check.gd` with the project's D-drive launcher/environment. The script writes ignored evidence to `artifacts/font-glyph-report.json`, exits nonzero on failure and checks the exact resource with all font fallbacks disabled.

Coverage includes the requested sample `生命 架势 破架 弹刀 重试 暂停 THE BELLKEEPER HP 08/08 0123456789`, the current compact-HUD Chinese vocabulary, Latin upper/lowercase, all digits, punctuation, `· / %`, and arrows. It measures numeric monospace advances, CJK widths, ascent/descent/line height, recommended integer baselines and exact 12-to-24px scaling. The report records missing Unicode codepoints explicitly. These are resource/metric checks, not a claim that gameplay was manually tested.

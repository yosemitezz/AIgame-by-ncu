shader_type canvas_item;
render_mode unshaded, blend_mix;
uniform vec4 outline_color : source_color = vec4(0.45, 0.96, 0.90, 1.0);
varying vec4 ghost_tint;
void vertex() { ghost_tint = COLOR; }
void fragment() {
    float center = texture(TEXTURE, UV).a;
    float inside = min(min(texture(TEXTURE, UV + vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a,
                           texture(TEXTURE, UV - vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a),
                       min(texture(TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a,
                           texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a));
    float edge = step(0.5, center) * (1.0 - step(0.5, inside));
    COLOR = vec4(outline_color.rgb * ghost_tint.rgb, edge * outline_color.a * ghost_tint.a);
}

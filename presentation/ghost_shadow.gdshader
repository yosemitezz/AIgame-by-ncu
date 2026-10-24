shader_type canvas_item;
render_mode unshaded, blend_mix;
// Hero shadow follower: a solid near-black silhouette with a thin violet rim so it still reads on dark stone.
uniform vec4 shadow_color : source_color = vec4(0.012, 0.0, 0.03, 1.0);
uniform vec4 rim_color : source_color = vec4(0.46, 0.14, 0.62, 1.0);
varying vec4 ghost_tint;
void vertex() { ghost_tint = COLOR; }
void fragment() {
    float center = texture(TEXTURE, UV).a;
    float inside = min(min(texture(TEXTURE, UV + vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a,
                           texture(TEXTURE, UV - vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a),
                       min(texture(TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a,
                           texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a));
    float body = step(0.5, center);
    float edge = body * (1.0 - step(0.5, inside));
    COLOR = vec4(mix(shadow_color.rgb, rim_color.rgb, edge * 0.75), body * ghost_tint.a);
}

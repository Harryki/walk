// =============================================================================
// Transition Texture Mask (Super Mario Style Iris Wipe)
// Adapted from Roadside Games godot-guides / guide_transition_texture_mask
// =============================================================================
shader_type canvas_item;
render_mode blend_mix;

uniform sampler2D mask_texture : source_color, filter_linear;
uniform float zoom : hint_range(0.0, 3.0) = 2.0;
uniform vec2 center = vec2(0.5, 0.5);
uniform vec4 wipe_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform bool use_procedural_circle = false;

void fragment() {
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	float screen_aspect = screen_size.x / screen_size.y;
	
	float mask_alpha = 0.0;
	
	if (!use_procedural_circle) {
		// Aspect ratio correction for texture
		vec2 tex_size = vec2(textureSize(mask_texture, 0));
		float tex_aspect = tex_size.x / max(tex_size.y, 0.001);
		
		float aspect_ratio = screen_aspect / max(tex_aspect, 0.001);
		vec2 correction = vec2(1.0, 1.0);
		correction.x = mix(aspect_ratio, 1.0, step(1.0, aspect_ratio));
		correction.y = mix(1.0 / aspect_ratio, 1.0, step(aspect_ratio, 1.0));
		
		vec2 adjusted_uv = (UV - 0.5) * correction + 0.5;
		vec2 zoomed_uv = (adjusted_uv - center) / max(zoom, 0.0001) + center;
		
		if (zoomed_uv.x >= 0.0 && zoomed_uv.x <= 1.0 && zoomed_uv.y >= 0.0 && zoomed_uv.y <= 1.0) {
			mask_alpha = texture(mask_texture, zoomed_uv).a;
		}
	} else {
		// High-performance procedural Mario iris circle
		vec2 uv_norm = UV - center;
		uv_norm.x *= screen_aspect;
		float dist = length(uv_norm);
		float radius = zoom * 0.75;
		float feather = 0.015;
		mask_alpha = 1.0 - smoothstep(max(radius - feather, 0.0), radius + feather, dist);
	}
	
	// Transparent inside circle (mask_alpha = 1), Black outside (mask_alpha = 0)
	COLOR = wipe_color;
	COLOR.a = wipe_color.a * (1.0 - mask_alpha);
}

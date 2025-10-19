@group(0) @binding(0) var inputTex: texture_2d<f32>;
@group(0) @binding(1) var outputTexture: texture_storage_2d<rgba16float, write>;
@group(0) @binding(2) var<uniform> bloomThreshold: f32;

@compute
@workgroup_size(8,8)
fn main(@builtin(global_invocation_id) idx: vec3u) {
	let dims = textureDimensions(inputTex);
	if(idx.x > dims.x || idx.y >= dims.y) {return;}

	let color = textureLoad(inputTex, vec2(idx.xy), 0).rgb;
	let brightness = dot(color, vec3f(0.2126, 0.7152, 0.0722));

	if(brightness > bloomThreshold) {
		textureStore(outputTexture, vec2(idx.xy), vec4f(color, 1.0));
	} else {
		textureStore(outputTexture, vec2(idx.xy), vec4(0.0));
	}

	return;
}
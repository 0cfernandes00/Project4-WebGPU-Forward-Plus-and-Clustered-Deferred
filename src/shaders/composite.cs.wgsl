@group(0) @binding(0) var sceneTexture: texture_2d<f32>;
@group(0) @binding(1) var bloomTexture: texture_2d<f32>;
@group(0) @binding(2) var outputTexture: texture_storage_2d<rgba16float,write>;
@group(0) @binding(3) var<uniform> bloomIntensity: f32;

@compute
@workgroup_size(8,8)
fn main(@builtin(global_invocation_id) idx: vec3u) {
	let dims = textureDimension(sceneTexture);
	if(idx.x > dims.x || idx.y >= dims.y) { return; }

	let scene = textureLoad(sceneTexture, vec2(idx.xy), 0).rgb;
	let bloom = textureLoad(blooTexture, vec2(idx.xy), 0).rgb;

	let finalCol = scene + bloom * bloomIntensity;
	textureStore(outputTexture, vec2(idx.xy), vec4f(finalCol, 1.0));
}
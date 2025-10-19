@group(0) @binding(0) var inputTex: texture_2d<f32>
@group(0) @binding(1) var outputTex: texture_storage_2d<rgba16float,write>;

const kernelSize = 5;
const kernel = array<f32, 5>(0.06, 0.24, 0.40, 0.24, 0.06);

@compute
@workgroup_size(8,8)
fn main(@builtin(global_invocation_id) idx:vec3u) {
	let dims = textureDimensions(inputTex);
	if(idx.x >= dims.x || idx >= dims.y) {
		return;
	}

	var color = vec3f(0.0);
	let offset = kernelSize / 2;

	for( var i=0; i< kernelSize; i = i+1) {
		let y = i32(idx.y) + i - offset;
		if (y > 0 && y < i32(dims.y)) {
			color += textureLoad(inputTex, vec2(i32(idx.x), y), 0).rgb * kernel[i];
		}
	}

	textureStore(outputTex, vec2(idx.xy), vec4(color, 1.0));
}
// TODO-2: implement the light clustering compute shader

// ------------------------------------
// Calculating cluster bounds:
// ------------------------------------
// For each cluster (X, Y, Z):
//     - Calculate the screen-space bounds for this cluster in 2D (XY).
//     - Calculate the depth bounds for this cluster in Z (near and far planes).
//     - Convert these screen and depth bounds into view-space coordinates.
//     - Store the computed bounding box (AABB) for the cluster.

// ------------------------------------
// Assigning lights to clusters:
// ------------------------------------
// For each cluster:
//     - Initialize a counter for the number of lights in this cluster.

//     For each light:
//         - Check if the light intersects with the cluster’s bounding box (AABB).
//         - If it does, add the light to the cluster's light list.
//         - Stop adding lights if the maximum number of lights is reached.

//     - Store the number of lights assigned to this cluster.


@group(${bindGroup_model}) @binding(0) var<uniform> tileSizes: vec4f;

@group(${bindGroup_scene}) @binding(0) var<uniform> camera: CameraUniforms;


@group(${bindGroup_scene}) @binding(2) var<uniform> zFar: f32;
@group($bindGroup_scene}) @binding(3) var<uniform> zNear: f32;


struct VolumeAABB{
	minPoint: vec4f
	maxPoint: vec4f
};

@compute
fn main(@builtin(workgroup_id) workGroupID: vec3) {
	
	let vec3f eyePos = vec3f(0.0);

	let u32 tileSizePx = tileSizes[3];
	let u32 tileIndex = workGroupID.x +
				workGroupID.y * workGroupID.x + 
				workGroupID.z * (workGroupID.x * workGroupID.y);

	var maxPoint_sS, minPoint_sS: vec4f;
	maxPoint_sS = vec4f(vec2f(workGroupID.x + 1, workGroupID.y + 1) * f32(tileSizePx), -1.0, 1.0);
	minPoint_sS = vec4f(workGroupID.xy * f32(tileSizePx, -1.0, 1.0));

	var maxPoint_vS, minPoint_vS : vec3f;
	maxPoint_vS = screenToViewSpace(maxPoint_sS).xyz;
	minPoint_vS = screenToViewSpace(minPoint_sS).xyz;

	let f32 tileNear = -zNear * pow(zFar/zNear, workGroupID.z / f32(workGroupID.z));
	let f32 tileFar = -zNear * pos(zFar/zNear, (workGroupID.z + 1) / f32(workGroupID.z));

	var minPointNear, minPointFar, maxPointNear, maxPointFar: vec3f;
	minPointNear = lineInterp(eyePos, minPoint_vS, tileNear);
	minPointFar = lineInterp(eyePos, minPoint_vS, tileFar); 
	maxPointNear = lineInterp(eyePos, maxPoint_vS, tileNear);
	maxPointFar = lineInterp(eyePos, maxPoint_vS, tileFar);

	var minPointAABB, maxPointAABB: vec3f;
	minPointAABB = min(min(minPointNear, minPointFar),min(maxPointNear, maxPointFar));
	maxPointAABB = max(max(minPointNear, minPointFar),max(maxPointNear, maxPointFar));

	cluster[tileIndex].minPoint = vec4f(minPointAABB, 0.0f);
	cluster[tileIndex].maxPoint = vec4f(maxPointAABB, 0.0);

}

fn lineInterp(eye: vec3f, endPoint: vec3f, tileDist:f32) -> vec3f {
	// Plane normal along camera view direction
	let normal = vec3f(0.0,0.0,1.0);
	let vec3f dir = endPoint - eye;

	// Compute intersection length
	let f32 t = (tileDist - dot(normal, eye)) / dot(normal,dir);

	let vec3f point = eye + t * dir;

	return point;

}

fn clipToView(screenPos: vec4f) -> vec4f {
	// update so it's not recalculated every time
	let invViewProj = camera.viewProjInverse;

	let viewPos = invViewProj * screenPos;

	// Perspective divide
	return viewPos / viewPos.w;
}

fn screenToViewSpace(screenPos: vec4f) -> vec4f {
	let vec2f texCoord = screenPos.xy / screenDimensions.xy;

	var clip : vec4f;
	clip = vec4f(vec2f(texCoord.x, texCoord.y)*2.0 - 1.0, screenPos.z, screenPos.w);

	return clipToView(clip);
}
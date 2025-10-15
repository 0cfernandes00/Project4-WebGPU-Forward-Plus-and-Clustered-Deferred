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

@group(0) @binding(0) var<storage, read_write> clusterSet: ClusterSet;
@group(0) @binding(1) var<storage, read_write> lightSet: LightSet;
@group(0) @binding(2) var<uniform> invViewProj: mat4x4f;
@group(0) @binding(3) var<uniform> screenDimensions: vec2f;


@compute
@workgroup_size(1, 1, 1) 
fn main(@builtin(global_invocation_id) globalID: vec3u) {

	let zNear: f32 = 0.1;
	let zFar: f32 = 1000.0;

	let xCount: u32 = 16u;
	let yCount: u32 = 9u;
	let zCount: u32 = 24u;

	if (globalID.x == 0 && globalID.y == 0 && globalID.z == 0) {
		clusterSet.numClusters = xCount * yCount * zCount;
	}
	
	let eyePos: vec3f = vec3f(0.0);
	let tileSizePx: f32 = screenDimensions.x / f32(xCount);
	let tileIndex : u32 = u32(globalID.x +
				globalID.y * xCount + 
				globalID.z * (xCount * yCount));

	
	let minPixelX: f32 = f32(globalID.x) * tileSizePx;
	let maxPixelX: f32 = f32(globalID.x + 1u) * tileSizePx;
	let minPixelY: f32 = f32(globalID.y) * tileSizePx;
	let maxPixelY: f32 = f32(globalID.y + 1u) * tileSizePx;

	let minPoint_sS: vec4f = vec4f(minPixelX, minPixelY, -1.0, 1.0);
	let maxPoint_sS: vec4f = vec4f(maxPixelX, maxPixelY, -1.0, 1.0);

	var maxPoint_vS: vec3f;
	var minPoint_vS: vec3f; 
	maxPoint_vS = screenToViewSpace(maxPoint_sS).xyz;
	minPoint_vS = screenToViewSpace(minPoint_sS).xyz;

	let tileNear: f32 = -zNear * pow(zFar/zNear, f32(globalID.z) / f32(globalID.z));
	let tileFar: f32 = -zNear * pow(zFar/zNear, f32(globalID.z + 1u) / f32(globalID.z));

	let minPointNear: vec3f = lineInterp(eyePos, minPoint_vS, tileNear);
	let minPointFar: vec3f = lineInterp(eyePos, minPoint_vS, tileFar); 
	let maxPointNear: vec3f = lineInterp(eyePos, maxPoint_vS, tileNear);
	let maxPointFar: vec3f = lineInterp(eyePos, maxPoint_vS, tileFar);

	let minPointAABB: vec3f = min(min(minPointNear, minPointFar),min(maxPointNear, maxPointFar));
	let maxPointAABB: vec3f = max(max(minPointNear, minPointFar),max(maxPointNear, maxPointFar));

	clusterSet.clusters[tileIndex].minPoint = vec4f(minPointAABB, 0.0f);
	clusterSet.clusters[tileIndex].maxPoint = vec4f(maxPointAABB, 0.0);

}

fn lineInterp(eye: vec3f, endPoint: vec3f, tileDist:f32) -> vec3f {
	// Plane normal along camera view direction
	let normal: vec3f = vec3f(0.0,0.0,1.0);
	let dir: vec3f = endPoint - eye;

	// Compute intersection length
	let t: f32 = (tileDist - dot(normal, eye)) / dot(normal,dir);

	let point: vec3f = eye + t * dir;

	return point;

}

fn clipToView(screenPos: vec4f) -> vec4f {
	// update so it's not recalculated every time
	//let invViewProj: mat4x4f = camera.viewProjInverse;

	let viewPos: vec4f = invViewProj * screenPos;

	// Perspective divide
	return viewPos / viewPos.w;
}

fn screenToViewSpace(screenPos: vec4f) -> vec4f {
	let texCoord: vec2f = screenPos.xy / screenDimensions.xy;

	let clip: vec4f = vec4f(vec2f(texCoord.x, texCoord.y)*2.0 - 1.0, screenPos.z, screenPos.w);

	return clipToView(clip);
}
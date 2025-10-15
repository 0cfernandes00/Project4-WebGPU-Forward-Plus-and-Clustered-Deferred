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
@group(0) @binding(4) var<uniform> viewMatrix: mat4x4f;


@compute
@workgroup_size(1, 1, 1) 
fn main(@builtin(global_invocation_id) gid: vec3u) {
let xCount: u32 = 16u;
    let yCount: u32 = 9u;
    let zCount: u32 = 24u;
    let clusterCount: u32 = xCount * yCount * zCount;

    let tx = gid.x;
    let ty = gid.y;
    let tz = gid.z;

    // ensure we are in range
    if (tx >= xCount || ty >= yCount || tz >= zCount) { return; }

    let clusterIdx = tx + ty * xCount + tz * (xCount * yCount);

    // compute tile extents in pixels
    let tileW: f32 = screenDimensions.x / f32(xCount);
    let tileH: f32 = screenDimensions.y / f32(yCount);

    let minPixelX = f32(tx) * tileW;
    let maxPixelX = f32(tx + 1u) * tileW;
    let minPixelY = f32(ty) * tileH;
    let maxPixelY = f32(ty + 1u) * tileH;

    // sample pixel centers (add 0.5) to avoid boundary issues
    let px0 = minPixelX + 0.5;
    let px1 = maxPixelX - 0.5;
    let py0 = minPixelY + 0.5;
    let py1 = maxPixelY - 0.5;

    // compute the 8 frustum corners for this tile in view space
    let c000 = screenPixelToView(px0, py0, 0.0); // near
    let c100 = screenPixelToView(px1, py0, 0.0);
    let c010 = screenPixelToView(px0, py1, 0.0);
    let c110 = screenPixelToView(px1, py1, 0.0);

    let c001 = screenPixelToView(px0, py0, 1.0); // far
    let c101 = screenPixelToView(px1, py0, 1.0);
    let c011 = screenPixelToView(px0, py1, 1.0);
    let c111 = screenPixelToView(px1, py1, 1.0);

    var minP = min(min(min(c000, c100), min(c010, c110)), min(min(c001, c101), min(c011, c111)));
    var maxP = max(max(max(c000, c100), max(c010, c110)), max(max(c001, c101), max(c011, c111)));

    // store the AABB in view-space into the cluster buffer
    clusterSet.clusters[clusterIdx].minPoint = vec4f(minP, 1.0);
    clusterSet.clusters[clusterIdx].maxPoint = vec4f(maxP, 1.0);

    // reset numLights
    //clusterSet.clusters[clusterIdx].numLights = 0u;

    // assign lights: transform light into view-space before testing
    let maxLightsPerCluster: u32 = 24u;
    var assigned: u32 = 0u;

    // optional: early-out if no lights
    let nLights = lightSet.numLights;
    for (var li: u32 = 0u; li < nLights; li = li + 1u) {
        if (assigned >= maxLightsPerCluster) { break; }
        let lightWorld = lightSet.lights[li].pos;
        let lightRadius = ${lightRadius}; // injected constant
        // transform light position to view space once
        let lightView = (viewMatrix * vec4f(lightWorld, 1.0)).xyz;

        //if (aabbIntersect(lightView, f32(lightRadius), minP, maxP)) {
            clusterSet.clusters[clusterIdx].lightIndices[assigned] = li;
            assigned = assigned + 1u;
        //}
    }

    clusterSet.clusters[clusterIdx].numLights = assigned;

    // optionally set clusterSet.numClusters once
    if (clusterIdx == 0u) {
        clusterSet.numClusters = clusterCount;
    }

    return;
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

	let viewPos: vec4f = invViewProj * screenPos;

	// Perspective divide
	return viewPos / viewPos.w;
}

fn screenPixelToView(px: f32, py: f32, clipZ: f32) -> vec3f {
    // px,py in pixel coords [0..screenDimensions]
    let ndcX = (px / screenDimensions.x) * 2.0 - 1.0;
    // flip Y from pixel coords (top-left) to NDC (usually -1 bottom -> +1 top)
    let ndcY = 1.0 - (py / screenDimensions.y) * 2.0;
    // WebGPU clip z is 0..1. Convert to clip space z in -1..1 if invViewProj expects that.
    let clipZ01 = clipZ; // 0.0 near, 1.0 far
    let clipZneg1to1 = clipZ01 * 2.0 - 1.0;
    let clip = vec4f(ndcX, ndcY, clipZneg1to1, 1.0);
    return (clipToView(clip)).xyz;
}

fn aabbIntersect(center: vec3f, radius: f32, aabbMin: vec3f, aabbMax: vec3f) -> bool {
    let clampedCenter = clamp(center, aabbMin, aabbMax);

    //let dist = length(clampedCenter - center);
	let dist2 = dot(center - clampedCenter, center - clampedCenter);

    return dist2 <= radius * radius;
}
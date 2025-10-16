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

@group(${bindGroup_scene}) @binding(0) var<uniform> camera: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read_write> clusterSet: ClusterSet;





@compute
@workgroup_size(${clusterWorkGroup}) 
fn main(@builtin(global_invocation_id) globalIdx: vec3u) {

    let clusterDim: vec3<u32> = vec3<u32>(16, 9, 24);
    let clusterIdx = globalIdx.x + globalIdx.y * clusterDim.x + globalIdx.z * clusterDim.x * clusterDim.y;
    if (globalIdx.x >= clusterDim.x || globalIdx.y >= clusterDim.y || globalIdx.z >= clusterDim.z) {
        return;
    }
    let currentCluster = &clusterSet.clusters[clusterIdx];

    //- Calculate the screen-space bounds for this cluster in 2D (XY).
    let clusterSize : vec2<f32> = camera.screenDimensions.xy / vec2<f32>(clusterDim.xy);
    let clusterSSBoundsMin : vec2<f32> =  vec2<f32>(globalIdx.xy) * clusterSize;
    let clusterSSBoundsMax : vec2<f32> = (vec2<f32>(globalIdx.xy) + 1.0) * clusterSize;

    let zNear = camera.zVector.x;
    let zFar = camera.zVector.y;


    //- Calculate the depth bounds for this cluster in Z (near and far planes).
    // Using exponential division scheme
    let clusterDepthMin : f32 = zNear * pow(zFar / zNear, f32(globalIdx.z) / f32(clusterDim.z)); //near plane
    let clusterDepthMax : f32 = zNear * pow(zFar / zNear, f32(globalIdx.z + 1u) / f32(clusterDim.z)); //far plane

    //- Convert these screen and depth bounds into view-space coordinates.
    let clusterVSBoundsMin : vec3<f32> = screenSpaceToViewSpace(clusterSSBoundsMin); 
    let clusterVSBoundsMax : vec3<f32> = screenSpaceToViewSpace(clusterSSBoundsMax);

    let clusterMinOnNear : vec3<f32> = clusterDepthMin / (-clusterVSBoundsMin.z) * clusterVSBoundsMin;
    let clusterMaxOnNear : vec3<f32> = clusterDepthMin / (-clusterVSBoundsMax.z) * clusterVSBoundsMax;
    let clusterMinOnFar : vec3<f32> = clusterDepthMax / (-clusterVSBoundsMin.z) * clusterVSBoundsMin;
    let clusterMaxOnFar : vec3<f32> = clusterDepthMax / (-clusterVSBoundsMax.z) * clusterVSBoundsMax;

    let minPoint : vec4<f32> = vec4<f32>(min(clusterMinOnNear, clusterMinOnFar), 0.0);
    let maxPoint : vec4<f32> = vec4<f32>(max(clusterMaxOnNear, clusterMaxOnFar), 0.0);

    (*currentCluster).minPoint = minPoint;
    (*currentCluster).maxPoint = maxPoint;


    var count : u32 = 0;
    let lightSetPtr = &(lightSet);

    for (var i : u32 = 0; i < (*lightSetPtr).numLights; i++)
    {
        let currentLight = (*lightSetPtr).lights[i];
        if (intersectLightClusterAABB(currentLight.pos, f32(${lightRadius}), minPoint.xyz, maxPoint.xyz))
        {
            if (count < ${maxLightsPerCluster}) {
                (*currentCluster).lightIndices[count] = i;
                count = count + 1u;
            }
            else {
                break;
            }
        }

    }
    (*currentCluster).numLights = count;
    //(*currentCluster).numLights = min(count, ${maxLightsPerCluster});

    return;


    /*
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
    let tileW: f32 = camera.screenDimensions.x / f32(xCount);
    let tileH: f32 = camera.screenDimensions.y / f32(yCount);

    let minPixelX = f32(tx) * tileW;
    let maxPixelX = f32(tx + 1u) * tileW;
    let minPixelY = f32(ty) * tileH;
    let maxPixelY = f32(ty + 1u) * tileH;

    // sample pixel centers (add 0.5) to avoid boundary issues
    let px0 = minPixelX;
    let px1 = maxPixelX;
    let py0 = minPixelY;
    let py1 = maxPixelY;


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

    let diag = maxP - minP;
    let expand = 0.002 * max(vec3f(1.0), diag); // scale relative to size but avoid zero
    minP = minP - expand;
    maxP = maxP + expand;

    // store the AABB in view-space into the cluster buffer
    clusterSet.clusters[clusterIdx].minPoint = vec4f(minP, 1.0);
    clusterSet.clusters[clusterIdx].maxPoint = vec4f(maxP, 1.0);

    // reset numLights
    //clusterSet.clusters[clusterIdx].numLights = 0u;

    // assign lights: transform light into view-space before testing
    let maxLightsPerCluster: u32 = ${maxLightsPerCluster};
    var assigned: u32 = 0u;

    let nLights = lightSet.numLights;

    for (var li: u32 = 0u; li < nLights; li = li + 1u) {
        if (assigned >= maxLightsPerCluster) { break; }
        let lightWorld = lightSet.lights[li].pos;
        let lightRadius = ${lightRadius}; // injected constant

        if (aabbIntersect(lightWorld, f32(lightRadius), minP, maxP)) {
            clusterSet.clusters[clusterIdx].lightIndices[assigned] = li;
            assigned = assigned + 1u;
        }
    }

    clusterSet.clusters[clusterIdx].numLights = assigned;
    //lightSet.numLights = assigned;
    
    return;
    */
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

fn screenSpaceToViewSpace(screenCoord: vec2<f32>) -> vec3<f32> {
    let screenDim: vec2f = screenCoord / camera.screenDimensions.xy;
    let ndc: vec4<f32> = vec4<f32>(screenDim * 2.0 - 1.0, -1.0, 1.0);

    var viewCoord: vec4<f32> = camera.invProjMat * ndc;
    viewCoord /= viewCoord.w;
    return vec3<f32>(viewCoord.xyz);
}

fn intersectLightClusterAABB(lightPos: vec3<f32>, lightRadius: f32, clusterMin: vec3<f32>, clusterMax: vec3<f32>) -> bool {
    let sphereCenter : vec4<f32> = camera.viewMatrix * vec4<f32>(lightPos, 1.0);
    let closetPoint : vec3<f32> = clamp(sphereCenter.xyz, clusterMin, clusterMax);
    let distanceSqr : f32 = dot(closetPoint - sphereCenter.xyz, closetPoint - sphereCenter.xyz);
    return (distanceSqr <= lightRadius * lightRadius);
}


fn screenPixelToView(px: f32, py: f32, clipZ: f32) -> vec3f {
    // px,py in pixel coords [0..screenDimensions]
    let ndcX = (px / camera.screenDimensions.x) * 2.0 - 1.0;
    // flip Y from pixel coords (top-left) to NDC (usually -1 bottom -> +1 top)
    let ndcY = 1.0 - (py / camera.screenDimensions.y) * 2.0;
    // WebGPU clip z is 0..1. Convert to clip space z in -1..1 if invViewProj expects that.
    let clipZ01 = clipZ; // 0.0 near, 1.0 far
    let clipZneg1to1 = clipZ01 * 2.0 - 1.0;
    let clip = vec4f(ndcX, ndcY, clipZneg1to1, 1.0);
    return vec3f(0.0);
    //return (clipToView(clip)).xyz;
}

fn aabbIntersect(center: vec3f, radius: f32, aabbMin: vec3f, aabbMax: vec3f) -> bool {
    let clampedCenter = clamp(center, aabbMin, aabbMax);

    //let dist = length(clampedCenter - center);
	let dist2 = dot(center - clampedCenter, center - clampedCenter);

    return dist2 <= radius * radius;
}
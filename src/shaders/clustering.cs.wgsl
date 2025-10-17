// TODO-2: implement the light clustering compute shader


@group(${bindGroup_scene}) @binding(0) var<uniform> camera: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read_write> clusterSet: ClusterSet;


@compute
@workgroup_size(8,8,4) 
fn main(@builtin(global_invocation_id) globalId: vec3u) {

    let xCount: u32 = 16u;
    let yCount: u32 = 9u;
    let zCount: u32 = 24u;
    let clusterCount: u32 = xCount * yCount * zCount;

    let clusterDim: vec3<u32> = vec3<u32>(xCount, yCount, zCount);

    let clusterIdx = globalId.x + globalId.y * xCount + globalId.z * xCount * yCount;
    if (globalId.x >= xCount|| globalId.y >= yCount || globalId.z >= zCount) {
        return;
    }


    let currentCluster = &clusterSet.clusters[clusterIdx];

    //- Calculate the screen-space bounds for this cluster in 2D (XY).

        // compute tile extents in pixels
    let tileW: f32 = camera.screenDimensions.x / f32(xCount);
    let tileH: f32 = camera.screenDimensions.y / f32(yCount);

    let clusterSize : vec2<f32> = vec2<f32>(tileW, tileH);

    let minPixelX = f32(globalId.x) * tileW;
    let maxPixelX = f32(globalId.x + 1u) * tileW;
    let minPixelY = f32(globalId.y) * tileH;
    let maxPixelY = f32(globalId.y + 1u) * tileH;
    let clusterSSBoundsMin : vec2<f32> =  vec2<f32>(minPixelX,minPixelY);
    let clusterSSBoundsMax : vec2<f32> = vec2<f32>(maxPixelX,maxPixelY);

    let zNear = camera.zVector.x;
    let zFar = camera.zVector.y;


    // calculate cluster bounds
    // Using exponential division scheme
    let clusterDepthMin : f32 = zNear * pow(zFar / zNear, f32(globalId.z) / f32(clusterDim.z)); 
    let clusterDepthMax : f32 = zNear * pow(zFar / zNear, f32(globalId.z + 1u) / f32(clusterDim.z)); 

    // convert bounds into view-space coordinates
    let clusterVSBoundsMin : vec3<f32> = screenPixelToView(clusterSSBoundsMin); 
    let clusterVSBoundsMax : vec3<f32> = screenPixelToView(clusterSSBoundsMax);

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
    let maxLightsPerCluster = 100u;

    for (var i : u32 = 0; i < (*lightSetPtr).numLights; i++)
    {
        let currentLight = (*lightSetPtr).lights[i];
        let viewPos = (camera.viewMatrix * vec4<f32>(currentLight.pos, 1.0)).xyz;

        if (aabbIntersect(viewPos, 2.0, minPoint.xyz, maxPoint.xyz))
        {
            if (count < maxLightsPerCluster) {
                (*currentCluster).lightIndices[count] = i;
                count = count + 1u;
            }
            else {
                break;
            }
        }

    }
    (*currentCluster).numLights = count;

    return;

}

fn screenPixelToView(point: vec2<f32>) -> vec3<f32> {
    let ndcX: f32 = (point.x / camera.screenDimensions.x) * 2.0 - 1.0;
    let ndcY: f32 = (point.y / camera.screenDimensions.y) * 2.0 - 1.0;

    var viewSpace: vec4<f32> = camera.invProjMat * vec4<f32>(ndcX, ndcY, -1.0, 1.0);

    viewSpace /= viewSpace.w;
    return vec3<f32>(viewSpace.xyz);
}

fn aabbIntersect(center: vec3f, radius: f32, aabbMin: vec3f, aabbMax: vec3f) -> bool {
    let clampedCenter = clamp(center, aabbMin, aabbMax);

	let dist2 = dot(center - clampedCenter, center - clampedCenter);

    return dist2 <= radius * radius;
}
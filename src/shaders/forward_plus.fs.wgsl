// TODO-2: implement the Forward+ fragment shader

// See naive.fs.wgsl for basic fragment shader setup; this shader should use light clusters instead of looping over all lights

// ------------------------------------
// Shading process:
// ------------------------------------
// Determine which cluster contains the current fragment.
// Retrieve the number of lights that affect the current fragment from the cluster’s data.
// Initialize a variable to accumulate the total light contribution for the fragment.
// For each light in the cluster:
//     Access the light's properties using its index.
//     Calculate the contribution of the light based on its position, the fragment’s position, and the surface normal.
//     Add the calculated contribution to the total light accumulation.
// Multiply the fragment’s diffuse color by the accumulated light contribution.
// Return the final color, ensuring that the alpha component is set appropriately (typically to 1).


@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;
@group(0) @binding(1) var<storage, read_write> lightSet: LightSet;
@group(0) @binding(2) var<uniform> camera: CameraUniforms;
@group(0) @binding(3) var<uniform> screenDimensions: vec2f;
@group(${bindGroup_scene}) @binding(4) var<storage, read> clusterSet: ClusterSet;

struct FragmentInput
{
    @builtin(position) fragCoord: vec4f,
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
    
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f {

    if (clusterSet.numClusters == 3456u) {
        //return vec4(0.0,1.0,0.0,1.0);
    }
    //return vec4(1.0,0.0,0.0,1.0);

    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    var totalLightContrib: vec3f = vec3f(0.0, 0.0, 0.0);

    let xCount: u32 = 16u;
	let yCount: u32 = 9u;
	let zCount: u32 = 24u;

    let tileWidth = screenDimensions.x / f32(xCount);
    let tileHeight = screenDimensions.y / f32(yCount);

    let scale : f32 = f32(zCount) / log2(camera.zVector.y / camera.zVector.x);
    let invLog2Scale : f32 = 1.0 / log2(scale);
    var zSlice: f32 = 0.0;
    zSlice = (in.pos.z - camera.zVector.x) / (camera.zVector.y - camera.zVector.x);
    zSlice = log2(zSlice * scale + 1.0) * invLog2Scale;
    zSlice = clamp(zSlice, 0.0, f32(zCount - 1u));

    // Transform world position to view space
    let viewPos = (camera.viewMat * vec4f(in.pos, 1.0)).xyz;
    
    let clusterIdx = u32(clamp(in.fragCoord.x / tileWidth, 0.0, f32(xCount - 1))) 
                    + u32(clamp(in.fragCoord.y / tileHeight, 0.0, f32(yCount - 1))) * xCount 
                    + u32(zSlice) * xCount * yCount;
 
    let cluster = clusterSet.clusters[clusterIdx];


    let cx = f32(clusterIdx % 16u) / 15.0;
    let cy = f32((clusterIdx / 16u) % 9u) / 8.0;
    let cz = f32(clusterIdx / (16u * 9u)) / 23.0; // zCount-1 = 23
    //return vec4f(cx, cy, cz, 1.0);


    let nl = f32(cluster.numLights) / 24.0;
    //return vec4f(nl, nl, nl, 1.0);


    let f = f32(cluster.lightIndices[0]) / f32(max(1u, lightSet.numLights));
    // return vec4(f, 0, 1-f, 1);

    
    let numLightsInCluster: u32 = cluster.numLights;
    for (var i = 0u; i < numLightsInCluster; i++) {
        let globalLightIndex = cluster.lightIndices[i];
        let light = lightSet.lights[globalLightIndex];
                
        totalLightContrib += calculateLightContrib(light, in.pos, normalize(in.nor));
    }

    let finalColor = diffuseColor.rgb * totalLightContrib;
    return vec4f(finalColor, 1.0);
    
}

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
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f {
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
    
    let clusterIdx = u32(clamp(in.pos.x / tileWidth, 0.0, f32(xCount - 1))) 
                    + u32(clamp(in.pos.y / tileHeight, 0.0, f32(yCount - 1))) * xCount 
                    + u32(zSlice) * xCount * yCount;
 
    let cluster = clusterSet.clusters[clusterIdx];
    if (in.pos.x >= cluster.minPoint.x && in.pos.x <= cluster.maxPoint.x &&
        in.pos.y >= cluster.minPoint.y && in.pos.y <= cluster.maxPoint.y &&
        in.pos.z >= cluster.minPoint.z && in.pos.z <= cluster.maxPoint.z) {

        let numLightsInCluster: u32 = cluster.numLights;
        for (var i = 0u; i < numLightsInCluster; i++) {
            let globalLightIndex = cluster.lightIndices[i];
            let light = lightSet.lights[globalLightIndex];
            totalLightContrib += calculateLightContrib(light, in.pos, normalize(in.nor));
        }
    }
   

    let finalColor = diffuseColor.rgb * totalLightContrib;
    return vec4f(finalColor, 1.0);
}

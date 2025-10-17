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
@group(${bindGroup_scene}) @binding(0) var<uniform> camera: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterSet: ClusterSet;

struct FragmentInput
{
    @builtin(position) fragCoord: vec4f,
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
    
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f {

    
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    var totalLightContrib: vec3f = vec3f(0.0, 0.0, 0.0);
    
    let zNear = camera.zVector.x;
    let zFar = camera.zVector.y;


    let xCount: u32 = 16u;
	let yCount: u32 = 9u;
	let zCount: u32 = 24u;

    let clusterDim: vec3<u32> = vec3<u32>(xCount, yCount, zCount);
    let VSPos : vec4<f32> = camera.viewMatrix * vec4<f32>(in.pos, 1.0);

    // calulate cluster z index using log scheme
    let clusterZ : u32 = u32((log(abs(VSPos.z) / zNear) * f32(clusterDim.z)) / log(zFar / zNear));
    let CSPos : vec4<f32> = camera.viewProj * vec4<f32>(in.pos, 1.0);
    let NDCPos : vec3<f32> = (CSPos.xyz / CSPos.w) * 0.5 + 0.5;
    let clusterX : u32 = u32(NDCPos.x * f32(clusterDim.x));
    let clusterY : u32 = u32(NDCPos.y * f32(clusterDim.y));

    // calculate cluster index
    let clusterIdx : u32 = clusterX + clusterY * clusterDim.x + clusterZ * clusterDim.x * clusterDim.y; 
 
    let cluster = clusterSet.clusters[clusterIdx];
    
    let numLightsInCluster: u32 = cluster.numLights;
    for (var i = 0u; i < numLightsInCluster; i++) {
        let globalLightIndex = cluster.lightIndices[i];
        let light = lightSet.lights[globalLightIndex];
                
        totalLightContrib += calculateLightContrib(light, in.pos, in.nor);
    }

    let finalColor = diffuseColor.rgb * totalLightContrib;
    return vec4f(finalColor, 1.0);
    
    
}

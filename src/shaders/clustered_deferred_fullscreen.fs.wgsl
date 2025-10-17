// TODO-3: implement the Clustered Deferred fullscreen fragment shader

// Similar to the Forward+ fragment shader, but with vertex information coming from the G-buffer instead.


@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;


@group(${bindGroup_scene}) @binding(0) var bufferPos: texture_2d<f32>;
@group(${bindGroup_scene}) @binding(1) var bufferAlbedo: texture_2d<f32>;
@group(${bindGroup_scene}) @binding(2) var bufferNormal: texture_2d<f32>;
@group(${bindGroup_scene}) @binding(3) var<uniform> camera: CameraUniforms;
@group(${bindGroup_scene}) @binding(4) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(5) var<storage, read> clusterSet: ClusterSet;


struct FragmentInput
{
    @builtin(position) fragCoord: vec4f,
    @location(0) uv: vec2f
    
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f {

    let pixelCoord: vec2<u32> = vec2<u32>(in.fragCoord.xy);
    let diffuseColor = textureLoad(bufferAlbedo, pixelCoord, 0).xyz;
    let worldPos = textureLoad(bufferPos, pixelCoord,0).xyz;
    let worldNormal = textureLoad(bufferNormal, pixelCoord, 0).xyz;
    var totalLightContrib: vec3f = vec3f(0.0, 0.0, 0.0);
    
    let zNear = camera.zVector.x;
    let zFar = camera.zVector.y;

    let xCount: u32 = 16u;
	let yCount: u32 = 9u;
	let zCount: u32 = 24u;

    
    let clusterDim: vec3<u32> = vec3<u32>(xCount, yCount, zCount);
    let VSPos : vec4<f32> = camera.viewMatrix * vec4<f32>(worldPos, 1.0);

    // calulate cluster z index using log scheme
    let clusterZ : u32 = u32((log(abs(VSPos.z) / zNear) * f32(clusterDim.z)) / log(zFar / zNear));
    let CSPos : vec4<f32> = camera.viewProj * vec4<f32>(worldPos, 1.0);
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

        totalLightContrib += calculateLightContrib(light, worldPos, worldNormal);
    }

    let finalColor = diffuseColor.rgb * totalLightContrib;
    return vec4f(finalColor, 1.0);
    
    
}

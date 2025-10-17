// TODO-3: implement the Clustered Deferred G-buffer fragment shader

// This shader should only store G-buffer information and should not do any shading.


@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput
{
    @builtin(position) fragCoord: vec4f,
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
    
}
struct FragmentOutput
{
    @location(0) position: vec4f,  // World position
    @location(1) albedo: vec4f,    // Diffuse color
    @location(2) normal: vec4f     // World normal
    
}

@fragment
fn main(in: FragmentInput) -> FragmentOutput {

    var output: FragmentOutput;

    output.normal = vec4(normalize(in.uv),0.0, 1.0);

    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    output.albedo = vec4f(diffuseColor.xyz, 1.0);

    output.position = vec4(in.pos,1.0);
    return output;
}

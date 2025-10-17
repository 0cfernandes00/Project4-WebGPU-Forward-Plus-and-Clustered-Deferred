// TODO-3: implement the Clustered Deferred fullscreen vertex shader

// This shader should be very simple as it does not need all of the information passed by the the naive vertex shader.


struct VertexOutput
{
    @builtin(position) fragPos: vec4f,
    @location(0) uv: vec2f,

}

@vertex
fn main(@builtin(vertex_index) vertexIndex: u32) -> VertexOutput
{

    var out: VertexOutput;
    let vertexPos = array<vec2f, 3> (
        vec2f(-1.0,-1.0),
        vec2f(3.0, -1.0),
        vec2f(-1.0, 3.0),
    );
    
    let x = vertexPos[vertexIndex].x;
    let y = vertexPos[vertexIndex].y;
    out.fragPos = vec4f(x, y, 0.0, 1.0);

    // Convert to 0-1 uv space
    out.uv = vec2f(x, y) * 0.5 + 0.5;  
    
    return out;
}
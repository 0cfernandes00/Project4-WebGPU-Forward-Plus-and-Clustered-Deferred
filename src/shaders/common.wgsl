// CHECKITOUT: code that you add here will be prepended to all shaders

struct Light {
    pos: vec3f,
    color: vec3f
}

struct LightSet {
    numLights: u32,
    lights: array<Light>
}

// TODO-2: you may want to create a ClusterSet struct similar to LightSet
struct VolumeAABB {
    minPoint: vec4f,              // 16 bytes
    maxPoint: vec4f,             // 16 bytes
    numLights: u32,     // 4 bytes
    lightIndices: array<u32, ${maxLightsPerCluster}> // 400 bytes
};

struct ClusterSet {
    numClusters: u32,
    clusters: array<VolumeAABB>
};

struct CameraUniforms {
    // TODO-1.3: add an entry for the view proj mat (of type mat4x4f)
    viewProj: mat4x4f,
    viewProjInverse: mat4x4f,
    viewMatrix: mat4x4f,
    invProjMat: mat4x4f,
    zVector: vec2f,
    screenDimensions: vec2f
}

// CHECKITOUT: this special attenuation function ensures lights don't affect geometry outside the maximum light radius
fn rangeAttenuation(distance: f32) -> f32 {
    return clamp(1.f - pow(distance / ${lightRadius}, 4.f), 0.f, 1.f) / (distance * distance);
}


fn calculateLightContrib(light: Light, posWorld: vec3f, nor: vec3f) -> vec3f {
    let vecToLight = light.pos - posWorld;
    let distToLight = length(vecToLight);

    let lambert = max(dot(nor, normalize(vecToLight)), 0.f);
    return light.color * lambert * rangeAttenuation(distToLight);
}


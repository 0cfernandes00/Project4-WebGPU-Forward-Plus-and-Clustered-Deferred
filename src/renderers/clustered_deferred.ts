import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { Stage } from '../stage/stage';

export class ClusteredDeferredRenderer extends renderer.Renderer {
    // TODO-3: add layouts, pipelines, textures, etc. needed for Forward+ here
    // you may need extra uniforms such as the camera view matrix and the canvas resolution

    sceneUniformsBindGroupLayout: GPUBindGroupLayout;
    sceneUniformsBindGroup: GPUBindGroup;

    depthTexture: GPUTexture;
    depthTextureView: GPUTextureView;

    gBufferPos: GPUTexture;
    gBufferPosView: GPUTextureView;

    gBufferNormal: GPUTexture;
    gBufferNormalView: GPUTextureView;

    gBufferAlbedo: GPUTexture;
    gBufferAlbedoView: GPUTextureView;

    pipeline: GPURenderPipeline;

    fullscreen_BindGroupLayout: GPUBindGroupLayout;
    fullscreen_BindGroup: GPUBindGroup;

    fullscreen_pipeline: GPURenderPipeline;

    constructor(stage: Stage) {
        super(stage);

        // TODO-3: initialize layouts, pipelines, textures, etc. needed for Forward+ here
        // you'll need two pipelines: one for the G-buffer pass and one for the fullscreen pass

        this.sceneUniformsBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "scene uniforms bind group layout",
            entries: [
                { // camera
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
                    buffer: { type: "uniform" }
                },
                { // lightSet
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" }
                },
                { // clusterBuffer
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" }
                }
            ]
        });

        this.sceneUniformsBindGroup = renderer.device.createBindGroup({
            label: "scene uniforms bind group",
            layout: this.sceneUniformsBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.camera.uniformsBuffer }
                },
                {
                    binding: 1,
                    resource: { buffer: this.lights.lightSetStorageBuffer }
                },
                {
                    binding: 2,
                    resource: { buffer: this.lights.clusterBuffer }
                }
            ]
        });

        this.gBufferPos = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "rgba32float",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.gBufferPosView = this.gBufferPos.createView();

        this.gBufferAlbedo = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "bgra8unorm",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.gBufferAlbedoView = this.gBufferAlbedo.createView();

        this.gBufferNormal = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "rgba16float",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.gBufferNormalView = this.gBufferNormal.createView();

        this.depthTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "depth24plus",
            usage: GPUTextureUsage.RENDER_ATTACHMENT
        });
        this.depthTextureView = this.depthTexture.createView();

        this.pipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "G- buffer pipeline layout",
                bindGroupLayouts: [
                    this.sceneUniformsBindGroupLayout,
                    renderer.modelBindGroupLayout,
                    renderer.materialBindGroupLayout
                ]
            }),
            depthStencil: {
                depthWriteEnabled: true,
                depthCompare: "less",
                format: "depth24plus"
            },
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "clustered vert shader",
                    code: shaders.naiveVertSrc
                }),
                buffers: [renderer.vertexBufferLayout]
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "clustered frag shader",
                    code: shaders.clusteredDeferredFragSrc,
                }),
                targets: [
                    { format: "rgba32float" },
                    { format: "bgra8unorm" },
                    { format: "rgba16float" },


                ]
            }
        });


        this.fullscreen_BindGroupLayout = renderer.device.createBindGroupLayout({
            label: "full screen pipe bind group layout",
            entries: [
                { // gBufferPos
                    binding: 0,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: { sampleType: "unfilterable-float", viewDimension: "2d", multisampled: false }
                },
                { // gBufferAlbedo
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: { sampleType: "float", viewDimension: "2d", multisampled: false }
                },
                { // gBufferNormal
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: { sampleType: "float", viewDimension: "2d", multisampled: false }
                },
                { // camera uniforms
                    binding: 3,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "uniform" }
                },
                { // lights
                    binding: 4,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" }
                },
                { // clusters
                    binding: 5,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" }
                }

            ]
        });

        this.fullscreen_BindGroup = renderer.device.createBindGroup({
            layout: this.fullscreen_BindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: this.gBufferPosView
                },
                {
                    binding: 1,
                    resource: this.gBufferAlbedoView 
                },
                {
                    binding: 2,
                    resource: this.gBufferNormalView
                },
                {
                    binding: 3,
                    resource: { buffer: this.camera.uniformsBuffer }
                },
                {
                    binding: 4,
                    resource: { buffer: this.lights.lightSetStorageBuffer }
                },
                {
                    binding: 5,
                    resource: { buffer: this.lights.clusterBuffer }
                }

            ]
        });

        this.fullscreen_pipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "clustered deferred pipeline layout",
                bindGroupLayouts: [
                    this.fullscreen_BindGroupLayout,
                ]
            }),
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "clustered deferred vert shader",
                    code: shaders.clusteredDeferredFullscreenVertSrc
                }),
                buffers: []
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "clustered deferred frag shader",
                    code: shaders.clusteredDeferredFullscreenFragSrc
                }),
                targets: [
                    {
                        format: renderer.canvasFormat,
                    }
                ]
            }
        });



    }

    override draw() {
        // TODO-3: run the Forward+ rendering pass:
        // - run the clustering compute shader
        // - run the G-buffer pass, outputting position, albedo, and normals
        // - run the fullscreen pass, which reads from the G-buffer and performs lighting calculations

        const encoder = renderer.device.createCommandEncoder();

        this.lights.doLightClustering(encoder);


        const renderPass = encoder.beginRenderPass({
            label: "deferred render pass",
            colorAttachments: [
                { view: this.gBufferPosView, loadOp: "clear", storeOp: "store", clearValue: [0, 0, 0, 0] },
                { view: this.gBufferAlbedoView, loadOp: "clear", storeOp: "store", clearValue: [0, 0, 0, 0] },
                { view: this.gBufferNormalView, loadOp: "clear", storeOp: "store", clearValue: [0, 0, 0, 0] }
            ],
            depthStencilAttachment: {
                view: this.depthTextureView,
                depthClearValue: 1.0,
                depthLoadOp: "clear",
                depthStoreOp: "store"
            }
        });
        renderPass.setPipeline(this.pipeline);

        renderPass.setBindGroup(shaders.constants.bindGroup_scene, this.sceneUniformsBindGroup);

        this.scene.iterate(node => {
            renderPass.setBindGroup(shaders.constants.bindGroup_model, node.modelBindGroup);
        }, material => {
            renderPass.setBindGroup(shaders.constants.bindGroup_material, material.materialBindGroup);
        },
            primitive => {
                renderPass.setVertexBuffer(0, primitive.vertexBuffer);
                renderPass.setIndexBuffer(primitive.indexBuffer, 'uint32');
                renderPass.drawIndexed(primitive.numIndices);
            });

        renderPass.end();

        const canvasTextureView = renderer.context.getCurrentTexture().createView();

        const lightingPass = encoder.beginRenderPass({
            label: "full screen render pass",
            colorAttachments: [{
                view: canvasTextureView,
                loadOp: "clear",
                storeOp: "store"
            }]
        });

        lightingPass.setPipeline(this.fullscreen_pipeline);
        lightingPass.setBindGroup(0, this.fullscreen_BindGroup);
        lightingPass.draw(3);
        lightingPass.end();

        renderer.device.queue.submit([encoder.finish()]);
    }
}

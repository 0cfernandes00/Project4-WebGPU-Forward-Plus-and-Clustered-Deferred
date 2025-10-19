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

    /*

    sceneTexture: GPUTexture;
    sceneTextureView: GPUTextureView;

    finalOutputTexture: GPUTexture;
    finalOutputTextureView: GPUTextureView;

    brightTexture: GPUTexture;
    brightTextureView: GPUTextureView;

    brightPipeline_BindGroupLayout: GPUBindGroupLayout;
    bright_BindGroup: GPUBindGroup;

    brightPipeline: GPUComputePipeline;

    blurHorizontalTexture: GPUTexture;
    blurHorizontalTextureView: GPUTextureView;

    blurHorizontal_BindGroupLayout: GPUBindGroupLayout;
    blurHorizontal_BindGroup: GPUBindGroup;

    blurHorizontalPipeline: GPUComputePipeline;

    blurVertical_BindGroupLayout: GPUBindGroupLayout;
    blurVertical_BindGroup: GPUBindGroup;

    blurVerticalPipeline: GPUComputePipeline;

    blurVerticalTexture: GPUTexture;
    blurVerticalTextureView: GPUTextureView;

    compositePipeline_BindGroupLayout: GPUBindGroupLayout;
    composite_BindGroup: GPUBindGroup;
    compositePipeline: GPUComputePipeline;
    */

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
        /*
        const textureDesc: GPUTextureDescriptor = {
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "rgba16float",
            usage: GPUTextureUsage.STORAGE_BINDING | GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.RENDER_ATTACHMENT
        };

        this.sceneTexture = renderer.device.createTexture(textureDesc);
        this.sceneTextureView = this.sceneTexture.createView();

        this.finalOutputTexture = renderer.device.createTexture(textureDesc);
        this.finalOutputTextureView = this.finalOutputTexture.createView();

        this.brightTexture = renderer.device.createTexture(textureDesc);
        this.brightTextureView = this.brightTexture.createView();

        this.brightPipeline_BindGroupLayout = renderer.device.createBindGroupLayout({
            label: "brightPipeline bind group layout",
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.COMPUTE,
                    texture: { sampleType: "float" }  // Input: scene texture
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.COMPUTE,
                    storageTexture: {
                        access: "write-only",
                        format: "rgba16float"  // Output: bright texture
                    }
                }
            ]
        });

        this.brightPipeline = renderer.device.createComputePipeline({
            layout: renderer.device.createPipelineLayout({
                label: "bloom pipeline layout",
                bindGroupLayouts: [this.brightPipeline_BindGroupLayout]
            }),
            compute: {
                module: renderer.device.createShaderModule({
                    label: "bloom compute shader",
                    code: shaders.bloomComputeSrc
                }),
                entryPoint: "main"
            }
        });

        this.bright_BindGroup = renderer.device.createBindGroup({
            label: "bloom bind group",
            layout: this.brightPipeline_BindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: this.sceneTextureView  // Input
                },
                {
                    binding: 1,
                    resource: this.brightTextureView  // Output
                }
            ]
        });

        this.blurHorizontalTexture = renderer.device.createTexture(textureDesc);
        this.blurHorizontalTextureView = this.blurHorizontalTexture.createView();

        this.blurHorizontal_BindGroupLayout = renderer.device.createBindGroupLayout({
            label: "blur horizontal bind group layout",
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.COMPUTE,
                    texture: { sampleType: "float" }  // Input: bright texture
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.COMPUTE,
                    storageTexture: {
                        access: "write-only",
                        format: "rgba16float"  // Output: blur H texture
                    }
                }
            ]
        });

        this.blurHorizontalPipeline = renderer.device.createComputePipeline({
            layout: renderer.device.createPipelineLayout({
                label: "blur horizontal compute pipeline layout",
                bindGroupLayouts: [this.blurHorizontal_BindGroupLayout]
            }),
            compute: {
                module: renderer.device.createShaderModule({
                    label: "blur horizontal compute shader",
                    code: shaders.blurHSrc
                }),
                entryPoint: "main"
            }
        });

        this.blurHorizontal_BindGroup = renderer.device.createBindGroup({
            label: "blur horizontal bind group",
            layout: this.blurHorizontal_BindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: this.brightTextureView  // Input
                },
                {
                    binding: 1,
                    resource: this.blurHorizontalTextureView  // Output
                }
            ]
        });


        this.blurVerticalTexture = renderer.device.createTexture(textureDesc);
        this.blurVerticalTextureView = this.blurVerticalTexture.createView();

        this.blurVertical_BindGroupLayout = renderer.device.createBindGroupLayout({
            label: "blur vertical bind group layout",
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.COMPUTE,
                    texture: { sampleType: "float" }  // Input: blur H texture
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.COMPUTE,
                    storageTexture: {
                        access: "write-only",
                        format: "rgba16float"  // Output: blur V texture
                    }
                }
            ]
        });

        this.blurVerticalPipeline = renderer.device.createComputePipeline({
            layout: renderer.device.createPipelineLayout({
                label: "blurVertical compute pipeline layout",
                bindGroupLayouts: [this.blurVertical_BindGroupLayout]
            }),
            compute: {
                module: renderer.device.createShaderModule({
                    label: "blur vertical compute shader",
                    code: shaders.blurVSrc
                }),
                entryPoint: "main"
            }
        });

        this.blurVertical_BindGroup = renderer.device.createBindGroup({
            label: "blurVertical bind group",
            layout: this.blurVertical_BindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: this.blurHorizontalTextureView  // Input
                },
                {
                    binding: 1,
                    resource: this.blurVerticalTextureView  // Output
                }
            ]
        });

        this.compositePipeline_BindGroupLayout = renderer.device.createBindGroupLayout({
            label: "composite bind group layout",
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.COMPUTE,
                    texture: { sampleType: "float" }  // Original scene
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.COMPUTE,
                    texture: { sampleType: "float" }  // Bloom result
                },
                {
                    binding: 2,
                    visibility: GPUShaderStage.COMPUTE,
                    storageTexture: {
                        access: "write-only",
                        format: "rgba16float"  // Final output
                    }
                }
            ]
        });

        this.composite_BindGroup = renderer.device.createBindGroup({
            label: "composite bind group",
            layout: this.compositePipeline_BindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: this.sceneTextureView
                },
                {
                    binding: 1,
                    resource: this.blurVerticalTextureView
                },
                {
                    binding: 2,
                    resource: this.finalOutputTextureView  // You'll need to create this
                }
            ]
        });

        this.compositePipeline = renderer.device.createComputePipeline({
            layout: renderer.device.createPipelineLayout({
                label: "composite compute pipeline layout",
                bindGroupLayouts: [this.compositePipeline_BindGroupLayout]
            }),
            compute: {
                module: renderer.device.createShaderModule({
                    label: "composite compute shader",
                    code: shaders.compositeSrc
                }),
                entryPoint: "main"
            }
        });
        */
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
               // { view: this.sceneTextureView, loadOp: "clear", storeOp: "store" },
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

        /*
        const brightPass = encoder.beginComputePass();
        brightPass.setPipeline(this.brightPipeline);
        brightPass.setBindGroup(0, this.bright_BindGroup);
        brightPass.dispatchWorkgroups(Math.ceil(renderer.canvas.width / 8), Math.ceil(renderer.canvas.height / 8));
        brightPass.end();

        const blurHPass = encoder.beginComputePass();
        blurHPass.setPipeline(this.blurHorizontalPipeline);
        blurHPass.setBindGroup(0, this.blurHorizontal_BindGroup);
        blurHPass.dispatchWorkgroups(Math.ceil(renderer.canvas.width / 8), Math.ceil(renderer.canvas.height / 8));
        blurHPass.end();

        const blurVPass = encoder.beginComputePass();
        blurVPass.setPipeline(this.blurVerticalPipeline);
        blurVPass.setBindGroup(0, this.blurVertical_BindGroup);
        blurVPass.dispatchWorkgroups(Math.ceil(renderer.canvas.width / 8), Math.ceil(renderer.canvas.height / 8));
        blurVPass.end();

        const compositePass = encoder.beginComputePass();
        compositePass.setPipeline(this.compositePipeline);
        compositePass.setBindGroup(0, this.composite_BindGroup);
        compositePass.dispatchWorkgroups(Math.ceil(renderer.canvas.width / 8), Math.ceil(renderer.canvas.height / 8));
        compositePass.end();
        */
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

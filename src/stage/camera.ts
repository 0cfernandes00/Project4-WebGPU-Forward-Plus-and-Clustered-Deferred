import { Mat4, mat4, Vec2, vec2, Vec3, vec3 } from "wgpu-matrix";
import { toRadians } from "../math_util";
import { device, canvas, fovYDegrees, aspectRatio } from "../renderer";

class CameraUniforms {
    readonly buffer = new ArrayBuffer(48*6);
    private readonly floatView = new Float32Array(this.buffer);

    set viewProjMat(mat: Float32Array) {
        // TODO-1.1: set the first 16 elements of `this.floatView` to the input `mat`

        this.floatView.set(mat.subarray(0,16), 0);
       
    }

    // TODO-2: add extra functions to set values needed for light clustering here
    set viewProjMatInverse(mat: Float32Array) {
        this.floatView.set(mat.subarray(0, 16), 16);
    }

    set viewMatrix(mat: Float32Array) {
        this.floatView.set(mat.subarray(0, 16), 32);
    }

    set invProjMat(mat: Float32Array) {
        this.floatView.set(mat.subarray(0, 16), 48);
    }

    set zVector(vec: Vec2) {
        this.floatView.set(vec.subarray(0, 2), 64);
    }
    set screenDimensions(vec: Vec2) {
        this.floatView.set(vec.subarray(0, 2), 66);
    }

    
}

export class Camera {
    uniforms: CameraUniforms = new CameraUniforms();
    uniformsBuffer: GPUBuffer;
    
    projMat: Mat4 = mat4.create();
    projMatInverse: Mat4 = mat4.create();
    cameraPos: Vec3 = vec3.create(-7, 2, 0);
    cameraFront: Vec3 = vec3.create(0, 0, -1);
    cameraUp: Vec3 = vec3.create(0, 1, 0);
    cameraRight: Vec3 = vec3.create(1, 0, 0);
    yaw: number = 0;
    pitch: number = 0;
    moveSpeed: number = 0.004;
    sensitivity: number = 0.15;
    zVector: Vec3 = vec3.create(0.1, 1000.0, 0.0);
    viewMat = mat4.create();


    static readonly nearPlane = 0.1;
    static readonly farPlane = 50.0;

    keys: { [key: string]: boolean } = {};

    constructor () {
        // TODO-1.1: set `this.uniformsBuffer` to a new buffer of size `this.uniforms.buffer.byteLength`
        // ensure the usage is set to `GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST` since we will be copying to this buffer
        // check `lights.ts` for examples of using `device.createBuffer()`
        //
        // note that you can add more variables (e.g. inverse proj matrix) to this buffer in later parts of the assignment

        this.uniformsBuffer = device.createBuffer({
            label: "uniforms",
            size: this.uniforms.buffer.byteLength,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
        });

        this.viewMatrixBuffer = device.createBuffer({
            label: "camera view matrix",
            size: 256,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
        });

        this.invViewProjBuffer = device.createBuffer({
            label: "inverse view proj matrix",
            size: 144,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
        });

        this.resolutionUniformBuffer = device.createBuffer({
            label: "resolution uniform buffer",
            size: 2 * 4,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
        });


        this.projMat = mat4.perspective(toRadians(fovYDegrees), aspectRatio, Camera.nearPlane, Camera.farPlane);
        //this.projMatInverse = mat4.inverse(this.projMat);

        this.rotateCamera(0, 0); // set initial camera vectors

        window.addEventListener('keydown', (event) => this.onKeyEvent(event, true));
        window.addEventListener('keyup', (event) => this.onKeyEvent(event, false));
        window.onblur = () => this.keys = {}; // reset keys on page exit so they don't get stuck (e.g. on alt + tab)

        canvas.addEventListener('mousedown', () => canvas.requestPointerLock());
        canvas.addEventListener('mouseup', () => document.exitPointerLock());
        canvas.addEventListener('mousemove', (event) => this.onMouseMove(event));
    }

    private onKeyEvent(event: KeyboardEvent, down: boolean) {
        this.keys[event.key.toLowerCase()] = down;
        if (this.keys['alt']) { // prevent issues from alt shortcuts
            event.preventDefault();
        }
    }

    private rotateCamera(dx: number, dy: number) {
        this.yaw += dx;
        this.pitch -= dy;

        if (this.pitch > 89) {
            this.pitch = 89;
        }
        if (this.pitch < -89) {
            this.pitch = -89;
        }

        const front = mat4.create();
        front[0] = Math.cos(toRadians(this.yaw)) * Math.cos(toRadians(this.pitch));
        front[1] = Math.sin(toRadians(this.pitch));
        front[2] = Math.sin(toRadians(this.yaw)) * Math.cos(toRadians(this.pitch));

        this.cameraFront = vec3.normalize(front);
        this.cameraRight = vec3.normalize(vec3.cross(this.cameraFront, [0, 1, 0]));
        this.cameraUp = vec3.normalize(vec3.cross(this.cameraRight, this.cameraFront));
    }

    private onMouseMove(event: MouseEvent) {
        if (document.pointerLockElement === canvas) {
            this.rotateCamera(event.movementX * this.sensitivity, event.movementY * this.sensitivity);
        }
    }

    private processInput(deltaTime: number) {
        let moveDir = vec3.create(0, 0, 0);
        if (this.keys['w']) {
            moveDir = vec3.add(moveDir, this.cameraFront);
        }
        if (this.keys['s']) {
            moveDir = vec3.sub(moveDir, this.cameraFront);
        }
        if (this.keys['a']) {
            moveDir = vec3.sub(moveDir, this.cameraRight);
        }
        if (this.keys['d']) {
            moveDir = vec3.add(moveDir, this.cameraRight);
        }
        if (this.keys['q']) {
            moveDir = vec3.sub(moveDir, this.cameraUp);
        }
        if (this.keys['e']) {
            moveDir = vec3.add(moveDir, this.cameraUp);
        }

        let moveSpeed = this.moveSpeed * deltaTime;
        const moveSpeedMultiplier = 3;
        if (this.keys['shift']) {
            moveSpeed *= moveSpeedMultiplier;
        }
        if (this.keys['alt']) {
            moveSpeed /= moveSpeedMultiplier;
        }

        if (vec3.length(moveDir) > 0) {
            const moveAmount = vec3.scale(vec3.normalize(moveDir), moveSpeed);
            this.cameraPos = vec3.add(this.cameraPos, moveAmount);
        }
    }

    onFrame(deltaTime: number) {
        this.processInput(deltaTime);

        const lookPos = vec3.add(this.cameraPos, vec3.scale(this.cameraFront, 1));
        const viewMat = mat4.lookAt(this.cameraPos, lookPos, [0, 1, 0]);
        const viewProjMat = mat4.mul(this.projMat, viewMat);
        // TODO-1.1: set `this.uniforms.viewProjMat` to the newly calculated view proj mat
        this.uniforms.viewProjMat = viewProjMat;

        // TODO-2: write to extra buffers needed for light clustering here
        this.projMatInverse = mat4.inverse(this.projMat);
        const viewProjMatInverse = mat4.inverse(viewProjMat);
        const resolutionData = new Float32Array([canvas.width, canvas.height]);

        this.uniforms.viewProjMatInverse = viewProjMatInverse;
        this.uniforms.zVector = vec2.create(Camera.nearPlane, Camera.farPlane);
        this.uniforms.viewMatrix = viewMat;
        this.uniforms.invProjMat = mat4.inverse(this.projMat);
        this.uniforms.screenDimensions = vec2.create(canvas.width, canvas.height);

        this.viewMat = viewMat;

        // TODO-1.1: upload `this.uniforms.buffer` (host side) to `this.uniformsBuffer` (device side)
        // check `lights.ts` for examples of using `device.queue.writeBuffer()`

        device.queue.writeBuffer(this.uniformsBuffer, 0, this.uniforms.buffer);

    }
}

# `VVMetalKit`

VVMetalKit is a framework that contains a number of basic Metal-based utilities I use for the various projects I work on.

## Overview

#### Essentials:

- `RenderProperties` is a global singleton for conveniently storing/retrieving values you'll use frequently.  This is the first thing you'll want to configure if you're using this framework.
- `VVMTLPool` is a texture and buffer pool- recycling textures and buffers is significantly faster than trashing and re-creating them every time you need one.  If you're working with Metal textures/buffers, this is probably the second thing you'll want to create.
- `VVMTLTextureImage-protocol` is a protocol/class that describes a poolable image in a Metal texture.  Instances of this class always come from `VVMTLPool`.  The texture may or may not be backed by either a CPU-based resource or a GPU-based resource, depending on how the texture/image was created by the pool.
- `VVMTLBuffer-protocol` is a protocol/class that describes a poolable buffer accessible to Metal.  Instances of this class always come from `VVMTLPool`.  The buffer may or may not be backed by shared memory, depending on how it was created by the pool.
- `VVMTLTextureImageView` is a high-level NSView subclass that uses Metal to display a `VVMTLTextureImage-protocol` as large as possible without cropping.  Under the hood, it uses `CustomMetalView`, which is an NSView that uses Metal to draw its contents- kind of like `MTKView`, which makes it more configurable...

#### Other useful classes:

- `VVMTLScene` is a superclass that contains a number of properties and methods used to "render content to a texture".  You probably won't work with it directly, but will instead want to subclass one of its subclasses:
- `VVMTLComputeScene` is a subclass of VVMTLScene that is used to perform compute-based rendering operations (`id<MTLComputeCommandEncoder>`).  This class is intended to be subclassed- `CopierMTLScene` is one such example.
- `VVMTLOrthoRenderScene` is a subclass of VVMTLRenderScene that is used to perform orthographic render-to-texture operations using `id<MTLRenderCommandEncoder>`.  This class is intended to be subclassed- `CMVMTLDrawObjectScene` is one such example.
- `VVMTLPerspRenderScene` is a subclass of VVMTLRenderScene similar that performs non-orthographic render-to-texture operations using `id<MTLRenderCommandEncoder>`.  This class is also intended to be subclassed.
- `CIMTLScene` is a subclass of `VVMTLScene` and a convenient way to render `CIImage` instances to texture/images.
- `CopierMTLScene` is a subclass of `VVMTLComputeScene` and a convenient way to copy a texture by running it through a compute shader, while optionally resizing the image using different sizing modes (fit/fill/copy).
- `CMVMTLDrawObject` is intended to simplify the process of drawing 2D shapes to textures- it encodes draw commands to geometry buffers which can be executed in arbitrary render contexts.  `CMVMTLDrawObjectScene` is a companion object- a subclass of `VVMTLScene` that allows you to render one or more draw objects to a texture.  `CMVMTLDrawObjectView` is another companion object that renders a draw object directly to a Metal view (it doesn't render to a texture).
- `VVMTLTextureLUT-protocol` is a protocol/class for a poolable, texture-backed LUT you can fetch from `VVMTLPool`.
- `VVMTLTimestamp` is a class that is used to timestamp objects vended by `VVMTLPool`.
- `VVMTLUtilities.h` contains a number of handy functions, particularly for boucing CGImageRefs to VVMTLTextureImages and vice versa.
- `AAPLMathUtilties.h` is provided by Apple, and contains a bunch of handy general-purpose math functions suited for using matrices to manipulate geometry.
- `CIImageAdditions.h` is a `CIImage` class addition that adds a strong ref to `CIImage` instances that retains a `VVMTLTextureImage-protocol` for the lifetime of the `CIImage`.
- `SwizzleMTLScene` is a class that uses Metal compute to do pixel format conversion on the GPU.
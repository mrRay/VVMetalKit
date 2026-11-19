//
//  VVMTLSurfaceImage+Swizzle.h
//  VVMetalKit
//
//  Created by testadmin on 6/22/26.
//

#ifndef VVMTLSurfaceImage_Swizzle_h
#define VVMTLSurfaceImage_Swizzle_h

#import <Foundation/Foundation.h>
#import <VVMetalKit/VVMTLSurfaceImage.h>
#import <VVMetalKit/SwizzleMTLSceneTypes.h>

@class SwizzleMTLScene;
@protocol VVMTLTextureImage;

NS_ASSUME_NONNULL_BEGIN




///	Bridges a ``VVMTLSurfaceImage`` to the ``SwizzleMTLScene`` vocabulary.  Keeps the facts about a CoreVideo format together: its ``SwizzlePF`` byte layout, its ``SwizzleColorRange`` signal range, AND its ``SwizzleColorPrimaries`` matrix family.
@interface VVMTLSurfaceImage (Swizzle)

///	The ``SwizzlePF`` byte layout corresponding to the surface's CoreVideo pixel format, or `SwizzlePF_Unknown` if unrecognized.
@property (readonly) SwizzlePF swizzlePixelFormat;

///	The ``SwizzleColorRange`` corresponding to the surface's CoreVideo pixel format (full for `'420f'`, video for `'420v'`/`'y420'`).  Defaults to `SwizzleColorRange_legacy` for formats whose range isn't determined here.
@property (readonly) SwizzleColorRange swizzleColorRange;

///	The ``SwizzleColorPrimaries`` corresponding to the surface's CoreVideo pixel format, resolved from the CVPixelBuffer's `kCVImageBufferYCbCrMatrixKey` attachment (601/709/2020).  Defaults to `SwizzleColorPrimaries_legacy` (== 709) when the attachment is absent, unrecognized, or the CVPixelBuffer is nil.
@property (readonly) SwizzleColorPrimaries swizzleColorPrimaries;

///	A ``SwizzleShaderImageInfo`` describing the surface (built from the surface's ACTUAL cached per-plane geometry- offset + bytesPerRow read independently per plane- via ``MakeSwizzleShaderImageInfoWithPlanes``, NOT naive layout-derived offsets).  The struct is role-agnostic; it is used both as a swizzle DESTINATION (encode) and as a SOURCE (decode).
@property (readonly) SwizzleShaderImageInfo swizzleDstImageInfo;

///	Builds a complete ``SwizzleShaderOpInfo`` to draw `inSrcInfo` into this surface (surface as DESTINATION), with `colorRange` and `colorPrimaries` already set from the surface's CoreVideo format.
- (SwizzleShaderOpInfo) makeSwizzleOpInfoFromSrcImageInfo:(SwizzleShaderImageInfo)inSrcInfo;

///	Builds a complete ``SwizzleShaderOpInfo`` to draw this surface into `inDstInfo` (surface as SOURCE), with `colorRange` and `colorPrimaries` already set from the surface's CoreVideo format.  The reverse of ``makeSwizzleOpInfoFromSrcImageInfo:``.
- (SwizzleShaderOpInfo) makeSwizzleOpInfoToDrawIntoDstImageInfo:(SwizzleShaderImageInfo)inDstInfo;

///	Convenience that decodes this surface into the passed RGB texture, building the op (surface as SOURCE, packed BGRA8 destination sized to `outRGB`) and dispatching it through `inScene`.
///	- Returns: NO if nothing was encoded into `inCB` (the scene refused the op; the reason is logged).  `outRGB` is then untouched.
- (BOOL) convertToRGBTexture:(id<VVMTLTextureImage>)outRGB scene:(SwizzleMTLScene *)inScene inCommandBuffer:(id<MTLCommandBuffer>)inCB;

///	Like ``convertToRGBTexture:scene:inCommandBuffer:``, but the scene reads each of the surface's planes as a texture made from the surface's CVPixelBuffer (through the global pool's CVMetalTextureCache) instead of reading `wholeSurfaceBuffer`- so the surface needs a `cvpb`, and doesn't need a `wholeSurfaceBuffer` or its plane geometry.  Only bi-planar 4:2:0 surfaces (`'420v'`/`'420f'`) are read this way.  The surface (and so its CVPixelBuffer) is kept alive until `inCB` completes.
///	- Returns: NO if nothing was encoded into `inCB`: the surface isn't bi-planar 4:2:0, it has no CVPixelBuffer, textures couldn't be made from its planes (logged, with the CoreVideo error), or the scene refused the op (logged).  The caller decides what to do instead (``convertToRGBTexture:scene:inCommandBuffer:`` reads the same surface through `wholeSurfaceBuffer`).
- (BOOL) convertPlaneTexturesToRGBTexture:(id<VVMTLTextureImage>)outRGB scene:(SwizzleMTLScene *)inScene inCommandBuffer:(id<MTLCommandBuffer>)inCB;

@end




NS_ASSUME_NONNULL_END

#endif /* VVMTLSurfaceImage_Swizzle_h */

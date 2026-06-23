//
//  VVMTLSurfaceImage.h
//  VVMetalKit
//
//  Created by testadmin on 6/22/26.
//

#ifndef VVMTLSurfaceImage_h
#define VVMTLSurfaceImage_h

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <CoreVideo/CoreVideo.h>
#import <IOSurface/IOSurface.h>

#import <VVMetalKit/VVMTLImage.h>
#import <VVMetalKit/VVMTLTimestamp.h>
#import <VVMetalKit/VVMTLRecycleable.h>
#import <VVMetalKit/VVMTLRecyclingPool.h>
#import <VVMetalKit/VVMTLRecycleableDescriptor.h>
#import <VVMetalKit/VVMTLSurfaceImageDescriptor.h>
#import <VVMetalKit/VVMTLBuffer.h>




///	The maximum number of planes a ``VVMTLSurfaceImage`` caches geometry for.  Matches the planar pixel formats VVMetalKit handles (e.g. 3-plane y420).
#define VVMTLSURFACEIMAGE_MAX_PLANES 3




/**		This protocol describes a pooled, IOSurface-backed planar image
		- The single backing IOSurface (owned by a `CVPixelBufferRef`) is exposed two ways aliasing the same memory: a whole-surface no-copy `id<VVMTLBuffer>` (the swizzle shader writes all planes here) and the `CVPixelBufferRef` (handed to the encoder).
		- Per-plane geometry (offset + bytesPerRow + dims) is cached, read INDEPENDENTLY per plane from `IOSurfaceGet…OfPlane` (chroma strides differ from luma- never assume `bytesPerRow * height`).
		- Do not create instances of this class directly- instead, ask `VVMTLPool` to generate them for you (they recycle, so the same `CVPixelBuffer`/`IOSurface` is reused frame to frame).
*/




@protocol VVMTLSurfaceImage <VVMTLImage, VVMTLTimestamp, VVMTLRecycleable>

+ (instancetype __nonnull) createWithDescriptor:(VVMTLSurfaceImageDescriptor * __nonnull)n;

- (instancetype __nonnull) initWithDescriptor:(VVMTLSurfaceImageDescriptor * __nonnull)n;

///	The primary backing.  Receiver "retains" the CVPixelBufferRef for its lifetime.  This is the single hand-off to the encoder.
@property (assign,readwrite,nullable) CVPixelBufferRef cvpb;
///	Derived from `cvpb`.  Receiver "retains" the IOSurfaceRef (CFRetain + IOSurfaceIncrementUseCount) for its lifetime.
@property (assign,readwrite,nullable) IOSurfaceRef iosfc;
///	A no-copy `id<VVMTLBuffer>` aliasing the whole IOSurface's memory (`IOSurfaceGetBaseAddress`).  The swizzle shader writes every plane into this by per-plane byte offset.
@property (strong,readwrite,nullable) id<VVMTLBuffer> wholeSurfaceBuffer;

///	The number of planes in the surface.
@property (assign,readwrite) NSUInteger planeCount;

///	The bytes per row of the given plane (read independently from `IOSurfaceGetBytesPerRowOfPlane`).
- (NSUInteger) bytesPerRowOfPlane:(NSUInteger)inPlaneIdx;
///	The byte offset of the given plane from the surface's base address (`IOSurfaceGetBaseAddressOfPlane - IOSurfaceGetBaseAddress`).
- (NSUInteger) offsetOfPlane:(NSUInteger)inPlaneIdx;
///	The width in pixels of the given plane.
- (NSUInteger) widthOfPlane:(NSUInteger)inPlaneIdx;
///	The height in pixels of the given plane.
- (NSUInteger) heightOfPlane:(NSUInteger)inPlaneIdx;

///	Used by `VVMTLPool` when generating the asset to cache the per-plane geometry.  You should not need to call this directly.
- (void) setPlaneCount:(NSUInteger)inPlaneCount offsets:(const NSUInteger * __nonnull)inOffsets bytesPerRows:(const NSUInteger * __nonnull)inBytesPerRows widths:(const NSUInteger * __nonnull)inWidths heights:(const NSUInteger * __nonnull)inHeights;

@end




@interface NSObject (VVMTLSurfaceImageNSObjectAdditions)
@property (readonly) BOOL isVVMTLSurfaceImage;
@end




/**	An object that conforms to the VVMTLSurfaceImage protocol describes an IOSurface-backed planar image, aliased as both a whole-surface no-copy MTLBuffer and a CVPixelBufferRef.
*/
@interface VVMTLSurfaceImage : NSObject <VVMTLSurfaceImage>
@end




#endif /* VVMTLSurfaceImage_h */

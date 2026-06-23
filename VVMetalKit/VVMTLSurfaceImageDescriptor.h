//
//  VVMTLSurfaceImageDescriptor.h
//  VVMetalKit
//
//  Created by testadmin on 6/22/26.
//

#ifndef VVMTLSurfaceImageDescriptor_h
#define VVMTLSurfaceImageDescriptor_h

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <CoreVideo/CoreVideo.h>

#import <VVMetalKit/VVMTLRecycleableDescriptor.h>

NS_ASSUME_NONNULL_BEGIN




///	Data container class.  Contents describe the relevant distinguishing characteristics of the IOSurface-backed CVPixelBuffer (and its derived resources) that we're going to recycle.  When retrieving objects from the pool, the values of this class are compared to the pool's contents to find a match.
///	- The pixel format is a CoreVideo `OSType` (NOT a `MTLPixelFormat`)- a biplanar YCbCr surface can't be expressed as a single `MTLPixelFormat`.




@interface VVMTLSurfaceImageDescriptor : NSObject <VVMTLRecycleableDescriptor>

+ (instancetype) createWithWidth:(NSUInteger)inWidth height:(NSUInteger)inHeight cvPixelFormat:(OSType)inCVPixelFormat storage:(MTLStorageMode)inStorage;

- (instancetype) initWithWidth:(NSUInteger)inWidth height:(NSUInteger)inHeight cvPixelFormat:(OSType)inCVPixelFormat storage:(MTLStorageMode)inStorage;

///	The width of the surface, in pixels.
@property (assign,readwrite) NSUInteger width;
///	The height of the surface, in pixels.
@property (assign,readwrite) NSUInteger height;
///	The CoreVideo pixel format (`OSType`) of the surface, e.g. `kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange`.
@property (assign,readwrite) OSType cvPixelFormat;
///	The storage mode of the whole-surface MTLBuffer view.
@property (assign,readwrite) MTLStorageMode storage;

@end




@interface NSObject (VVMTLSurfaceImageDescriptorNSObjectAdditions)
@property (readonly) BOOL isVVMTLSurfaceImageDescriptor;
@end




NS_ASSUME_NONNULL_END

#endif /* VVMTLSurfaceImageDescriptor_h */

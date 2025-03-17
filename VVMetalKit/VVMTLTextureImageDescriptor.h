//
//  VVMTLTextureImageDescriptor.h
//  VVMetalKit
//
//  Created by testadmin on 6/26/23.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#import <VVMetalKit/VVMTLRecycleableDescriptor.h>

NS_ASSUME_NONNULL_BEGIN




///	Data container class.  Contents describe the relevant distinguishing characteristics of the GPU resource (and associated CPU resources, if any) that we're going to recycle.  When retrieving objects from the pool, the values of this class are compared the pool's contents to find a match.




@interface VVMTLTextureImageDescriptor : NSObject <VVMTLRecycleableDescriptor>

+ (instancetype) createWithWidth:(NSUInteger)inWidth height:(NSUInteger)inHeight pixelFormat:(MTLPixelFormat)inPfmt storage:(MTLStorageMode)inStorage usage:(MTLTextureUsage)inUsage bytesPerRow:(NSUInteger)inBytesPerRow;

- (instancetype) initWithWidth:(NSUInteger)inWidth height:(NSUInteger)inHeight pixelFormat:(MTLPixelFormat)inPfmt storage:(MTLStorageMode)inStorage usage:(MTLTextureUsage)inUsage bytesPerRow:(NSUInteger)inBytesPerRow;

///	The width of the GPU resource, in pixels.
@property (assign,readwrite) NSUInteger width;
///	The height of the GPU resource, in pixels.
@property (assign,readwrite) NSUInteger height;
///	Defaults to MTLTextureType2D, also recognizes 'MTLTextureType2DMultisample'
@property (assign,readwrite) MTLTextureType textureType;
///	Defaults to 1
@property (assign,readwrite) NSUInteger sampleCount;
///	The pixel format of the GPU resource.
@property (assign,readwrite) MTLPixelFormat pfmt;
///	The storage 
@property (assign,readwrite) MTLStorageMode storage;
@property (assign,readwrite) MTLTextureUsage usage;
@property (assign,readwrite) BOOL mtlBufferBacking;	//	NO by default, if YES we're looking for a texture backed by a id<VVMTLBuffer>
@property (assign,readwrite) BOOL iosfcBacking;	//	NO by default, if YES we're looking for a texture backed by an IOSurfaceRef
@property (assign,readwrite) BOOL cvpbBacking;	//	NO by default, if YES we're looking for a texture backed by a CVPixelBufferRef (or maybe a texture backed by an IOSurface backed by a CVPixelBufferRef!)
@property (assign,readwrite) NSUInteger bytesPerRow;	//	0 by default- convenience variable, used to pass specific bytes per row values around when there is a backing with padding

@end




@interface NSObject (VVMTLTextureImageDescriptorNSObjectAdditions)
@property (readonly) BOOL isVVMTLTextureImageDescriptor;
@end




NS_ASSUME_NONNULL_END

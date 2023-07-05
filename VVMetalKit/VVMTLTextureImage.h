//
//  VVMTLTextureImage.h
//  VVMetalKit
//
//  Created by testadmin on 6/23/23.
//

#ifndef MTLTextureImage_h
#define MTLTextureImage_h

#import <Metal/Metal.h>

#import <VVMetalKit/VVMTLImage.h>
#import <VVMetalKit/VVMTLTimestamp.h>
#import <VVMetalKit/VVMTLRecycleable.h>
#import <VVMetalKit/VVMTLRecyclingPool.h>
#import <VVMetalKit/VVMTLRecycleableDescriptor.h>
#import <VVMetalKit/VVMTLTextureImageDescriptor.h>
#import <VVMetalKit/VVMTLTextureImageShaderTypes.h>
#import <VVMetalKit/VVMTLBuffer.h>




@protocol VVMTLTextureImage <VVMTLImage, VVMTLTimestamp, VVMTLRecycleable>

+ (instancetype __nonnull) createWithDescriptor:(VVMTLTextureImageDescriptor * __nonnull)n;

- (instancetype __nonnull) initWithDescriptor:(VVMTLTextureImageDescriptor * __nonnull)n;

@property (strong,readwrite,nonnull) id<MTLTexture> texture;

//	If non-null, provides the backing for the texture. Receiver "retains" the id<VVMTLBuffer> for its lifetime.
@property (strong,readwrite,nullable) id<VVMTLBuffer> buffer;
//	If non-null, provides the backing for the texture. Receiver "retains" the IOSurfaceRef for its lifetime.
@property (assign,readwrite,nullable) IOSurfaceRef iosfc;
//	If non-null, provides the backing for the texture (and maybe the iosfc). Receiver "retains" the CVPixelBufferRef for its lifetime.
@property (assign,readwrite,nullable) CVPixelBufferRef cvpb;

//	this is a convenience property- if it's non-zero, the backend will use it when allocating texture backings.  if it's 0 (the default value), the backend will automatically calculate an appropriate bytesPerRow.  you should use this if the bytesPerRow of your backing have any padding or alignment requirements.
@property (assign,readwrite) size_t bytesPerRow;

//	populates the pased struct ptr with data that describes how to draw this image, taking into account the src rect and h/v flippedness
- (void) populateStruct:(struct VVMTLTextureImageStruct * __nullable)n;

@end




@interface NSObject (VVMTLTextureImageNSObjectAdditions)
@property (readonly) BOOL isVVMTLTextureImage;
@end




@interface VVMTLTextureImage : NSObject <VVMTLTextureImage>
@end




#endif /* MTLTextureImage_h */

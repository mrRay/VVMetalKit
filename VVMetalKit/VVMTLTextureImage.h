//
//  VVMTLTextureImage.h
//  VVMetalKit
//
//  Created by testadmin on 6/23/23.
//

#ifndef MTLTextureImage_h
#define MTLTextureImage_h

#import <Metal/Metal.h>

#import "VVMTLImage.h"
#import "VVMTLTimestamp.h"
#import "VVMTLRecycleable.h"
#import "VVMTLRecyclingPool.h"
#import "VVMTLRecycleableDescriptor.h"
#import "VVMTLTextureImageDescriptor.h"

#import "VVMTLBuffer.h"




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

@end




@interface NSObject (VVMTLTextureImageNSObjectAdditions)
@property (readonly) BOOL isVVMTLTextureImage;
@end




@interface VVMTLTextureImage : NSObject <VVMTLTextureImage>
@end




#endif /* MTLTextureImage_h */

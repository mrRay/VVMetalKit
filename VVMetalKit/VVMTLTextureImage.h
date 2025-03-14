//
//  VVMTLTextureImage.h
//  VVMetalKit
//
//  Created by testadmin on 6/23/23.
//

#ifndef MTLTextureImage_h
#define MTLTextureImage_h

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <CoreImage/CoreImage.h>

#import <VVMetalKit/VVMTLImage.h>
#import <VVMetalKit/VVMTLTimestamp.h>
#import <VVMetalKit/VVMTLRecycleable.h>
#import <VVMetalKit/VVMTLRecyclingPool.h>
#import <VVMetalKit/VVMTLRecycleableDescriptor.h>
#import <VVMetalKit/VVMTLTextureImageDescriptor.h>
#import <VVMetalKit/VVMTLTextureImageShaderTypes.h>
#import <VVMetalKit/VVMTLBuffer.h>




/**		This protocol describes an image with a Metal texture representation.
		- Implemented primarily by an actual class (`VVMTLTextureImage`)
		- The texture itself can have different kinds of backings- from Metal buffers to IOSurfaces to CVPixelBuffers
		- The main goals of this protocol/class are to create a wrapper allowing for easy reuse/recycling of textures, and to make a higher-level workflow that simplifies the process of making textures from various backings.
		- Do not create instances of this class directly- instead, ask `VVMTLPool` to generate them for you.
*/




@protocol VVMTLTextureImage <VVMTLImage, VVMTLTimestamp, VVMTLRecycleable>

+ (instancetype __nonnull) createWithDescriptor:(VVMTLTextureImageDescriptor * __nonnull)n;

- (instancetype __nonnull) initWithDescriptor:(VVMTLTextureImageDescriptor * __nonnull)n;

@property (strong,readwrite,nonnull) id<MTLTexture> texture;

///	If non-null, provides the backing for the texture. Receiver "retains" the id<VVMTLBuffer> for its lifetime.
@property (strong,readwrite,nullable) id<VVMTLBuffer> buffer;
///	If non-null, provides the backing for the texture. Receiver "retains" the IOSurfaceRef for its lifetime.
@property (assign,readwrite,nullable) IOSurfaceRef iosfc;
///	If non-null, provides the backing for the texture (and maybe the iosfc). Receiver "retains" the CVPixelBufferRef for its lifetime.
@property (assign,readwrite,nullable) CVPixelBufferRef cvpb;

///	This is a convenience property- if it's non-zero, the backend will use it when allocating texture backings.  if it's 0 (the default value), the backend will automatically calculate an appropriate bytesPerRow.  You should use this if the bytesPerRow of your backing have any padding or alignment requirements.
@property (assign,readwrite) size_t bytesPerRow;

///	Populates the passed struct ptr with data that describes how to draw this image, taking into account the src rect and h/v flippedness.
- (void) populateStruct:(struct VVMTLTextureImageStruct * __nullable)n;

///	Creates and returns a CIImage backed by the receiver's id<MTLTexture>, taking into account cropping and flippedness.  IMPORTANT: the returned CIImage RETAINS THE TEXTURE OBJECT THAT GENERATED IT FOR THE LIFETIME OF THE CIImage!
- (CIImage * __nonnull) createCIImageWithColorSpace:(CGColorSpaceRef __nullable)cs;

///	The 'srcRect' property of a VVMTLImage uses a coordinate system with an origin in the bottom-left corner of the window.  metal expects a coordinate system that uses the top-left corner as the origin.
@property (readonly) NSRect mtlSrcRect;

@end




@interface NSObject (VVMTLTextureImageNSObjectAdditions)
@property (readonly) BOOL isVVMTLTextureImage;
@end



/**	An object that conforms to the VVMTLTextureImage protocol describes an image held by a GPU texture, optionally backed by a Metal buffer, IOSurface, or CVPixelBufferRef.
*/
@interface VVMTLTextureImage : NSObject <VVMTLTextureImage>
@end




#endif /* MTLTextureImage_h */

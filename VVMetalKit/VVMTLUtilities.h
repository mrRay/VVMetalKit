//
//  VVMTLUtilities.h
//  VVMetalKit
//
//  Created by testadmin on 7/5/23.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Metal/Metal.h>
#import <simd/simd.h>

@protocol VVMTLTextureImage;

//NS_ASSUME_NONNULL_BEGIN



#if defined __cplusplus
extern "C"	{
#endif

///	Un-premultiplies the image data in the passed context
void CGBitmapContextUnpremultiply(CGContextRef ctx);

///	Creates a CGImageRef from the passed Metal texture/image, of its srcRect's size and holding only its srcRect
CGImageRef CreateCGImageRefFromVVMTLTextureImage(id<VVMTLTextureImage> inImg);
///	Resizes a Metal texture/image and then creates a CGImageRef from it: the image is 'imgSize', with the image's srcRect fitted into it by SizingModeFit (aspect ratio kept, any letter- or pillarbox transparent black).  Answers NULL, with an error logged, where 'imgSize' rounds to less than one pixel in either dimension
CGImageRef CreateCGImageRefFromResizedVVMTLTextureImage(id<VVMTLTextureImage> inImg, NSSize imgSize);

///	Creates a CGImageRef from a raw id<MTLTexture>, of the texture's size, in sRGB, releasing every reference it takes to the colour space.  8-bit BGRA and RGBA textures give 8-bit RGBA images, RGBA16Float and RGBA32Float give float images of their own depth, and RGBA16Uint gives an 8-bit RGBA image, each component scaled from the 16-bit range; any other format answers NULL with an error logged.  Every CGImage path in this file reads the texture's bytes through this function, which first copies a private texture to a CPU-readable one and synchronizes a managed texture (or the buffer backing it) on RenderProperties.global.bgCmdQueue, waiting for that to complete.  The synchronize orders only against GPU work on that queue or already complete, so the caller must have waited for every write to the texture made on any other queue, or made it on bgCmdQueue and committed it, before calling.  The image's alpha is tagged premultiplied (kCGImageAlphaPremultipliedLast, with the float formats' float and byte-order flags) whatever the texture holds, because these textures are output, a picture composited for display, and premultiplied is how such a picture is held, where straight alpha is how an asset is held for use inside another image: VVMetalKit's render scenes, which blend over transparent black, and VVP5JS's output at its default store premultiplied colour.  The bytes are copied as the texture holds them, never premultiplied or unpremultiplied, so a texture holding straight colour, as CIMTLScene's output does and as a texture uploaded by CreateTextureFromCGImage from a straight-alpha CGImage does, is mis-described wherever it is not opaque.
CGImageRef CreateCGImageRefFromMTLTexture(id<MTLTexture> inTex);
///	Resizes a raw id<MTLTexture> and creates a CGImageRef from it: the image is 'imgSize', with the texture fitted into it by SizingModeFit (aspect ratio kept, any letter- or pillarbox transparent black).  Answers NULL, with an error logged, where 'imgSize' rounds to less than one pixel in either dimension
CGImageRef CreateCGImageRefFromResizedMTLTexture(id<MTLTexture> inTex, NSSize imgSize);

///	Creates a Metal texture/image from the passed CGImageRef
id<VVMTLTextureImage> CreateTextureFromCGImage(CGImageRef inImg);
///	Resizes the passed CGImageRef and creates a Metal texture/image from it
id<VVMTLTextureImage> CreateTextureFromResizedCGImage(CGImageRef inImg, NSSize imgSize);

///	Makes an NSString from the passed OSType (basically a FourCC)
NSString * NSStringFromOSType(OSType n);
///	Makes an NSString from the passed MTLPixelFormat
NSString * NSStringFromMTLPixelFormat(MTLPixelFormat n);

///	Extracts the components of the passed NSColor and returns a float4 vector with their values
vector_float4 Vec4FromNSColor(NSColor * inColor);

///	Convenience method for quickly determining whether or not the passed MTLPixelFormat contains floating-point data
BOOL IsMTLPixelFormatFloatingPoint(MTLPixelFormat inPfmt);
///	Convenience method for quickly determining whether or not the passed MTLPixelFormat contains compressed data (like BCX, PVRTC, EAC, ASTC, etc)
BOOL IsMTLPixelFormatCompressed(MTLPixelFormat n);

///	Makes a "best guess" as to the minimum number of bytes per row for the passed pixel format.  The size is passed as a ptr, and its value will be adjusted if a pixel format has specific size requirements
size_t BytesPerRowFromMTLPixelFormatAndSize(MTLPixelFormat inPfmt, NSSize * inoutSize);

///	There are important nuanced differences between MTLResourceOptions and MTLStorageMode, but sometimes you want a naive conversion from storage mode to resource option.
MTLResourceOptions MTLResourceStorageModeForMTLStorageMode(MTLStorageMode inStorage);

///	Attempts to return a CVPixelFormat for the passed MTLPixelFormat.  Not all pixel formats can be converted, but sometimes you want a naive guess as to the best CoreVideo format for a given Metal pixel format.
OSType BestGuessCVPixelFormatTypeForMTLPixelFormat(MTLPixelFormat inPF);


#if defined __cplusplus
}
#endif




@interface NSImage (NSImageVVMTLUtilities)

+ (NSImage *) createFromMTLTexture:(id<MTLTexture>)n;
+ (NSImage *) createFromMTLTexture:(id<MTLTexture>)n sized:(NSSize)inSize;

@end




//NS_ASSUME_NONNULL_END

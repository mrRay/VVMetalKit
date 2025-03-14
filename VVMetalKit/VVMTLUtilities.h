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

///	Creates a CGImageRef from the passed Metal texture/image
CGImageRef CreateCGImageRefFromVVMTLTextureImage(id<VVMTLTextureImage> inImg);
///	Resizes a Metal texture/image and then creates a CGImageRef from it
CGImageRef CreateCGImageRefFromResizedVVMTLTextureImage(id<VVMTLTextureImage> inImg, NSSize imgSize);

///	Creates a CGImageRef from a raw id<MTLTexture>
CGImageRef CreateCGImageRefFromMTLTexture(id<MTLTexture> inTex);
///	Resizes a raw id<MTLTexture> and creates a CGImageRef from it
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

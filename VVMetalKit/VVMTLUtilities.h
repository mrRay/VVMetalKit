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

void CGBitmapContextUnpremultiply(CGContextRef ctx);

CGImageRef CreateCGImageRefFromVVMTLTextureImage(id<VVMTLTextureImage> inImg);
CGImageRef CreateCGImageRefFromResizedVVMTLTextureImage(id<VVMTLTextureImage> inImg, NSSize imgSize);

CGImageRef CreateCGImageRefFromMTLTexture(id<MTLTexture> inTex);
CGImageRef CreateCGImageRefFromResizedMTLTexture(id<MTLTexture> inTex, NSSize imgSize);

id<VVMTLTextureImage> CreateTextureFromCGImage(CGImageRef inImg);
id<VVMTLTextureImage> CreateTextureFromResizedCGImage(CGImageRef inImg, NSSize imgSize);

NSString * NSStringFromOSType(OSType n);
NSString * NSStringFromMTLPixelFormat(MTLPixelFormat n);

vector_float4 Vec4FromNSColor(NSColor * inColor);

BOOL IsMTLPixelFormatFloatingPoint(MTLPixelFormat inPfmt);

//	the size is passed as a ptr, and its value will be adjusted if a pixel format has specific size requirements
size_t BytesPerRowFromMTLPixelFormatAndSize(MTLPixelFormat inPfmt, NSSize * inoutSize);

MTLResourceOptions MTLResourceStorageModeForMTLStorageMode(MTLStorageMode inStorage);
OSType BestGuessCVPixelFormatTypeForMTLPixelFormat(MTLPixelFormat inPF);

#if defined __cplusplus
}
#endif




@interface NSImage (NSImageVVMTLUtilities)

+ (NSImage *) createFromMTLTexture:(id<MTLTexture>)n;
+ (NSImage *) createFromMTLTexture:(id<MTLTexture>)n sized:(NSSize)inSize;

@end




//NS_ASSUME_NONNULL_END

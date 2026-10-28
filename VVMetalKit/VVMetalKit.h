#import <Foundation/Foundation.h>

//! Project version number for VVMetalKit.
FOUNDATION_EXPORT double VVMetalKitVersionNumber;

//! Project version string for VVMetalKit.
FOUNDATION_EXPORT const unsigned char VVMetalKitVersionString[];

//	the API version of this framework, readable at runtime.  it is raised by every behaviour change, and is for the changes
//	that deserve a report rather than a refusal: a client weak-imports it, treats absent as too old, and declines or falls
//	back on whatever an older copy lacks.  DYLIB_COMPATIBILITY_VERSION, which dyld enforces at launch, moves only for a
//	change a stale copy must not be allowed to run with.
//	1 is the first versioned release.
//	2 is CMVMTLDrawObject's index type: the initializer and the two create methods that take an 'indexType', the
//	'indexType', 'bytesPerIndex', 'restartIndex' and 'maxVertexCount' properties, and every encoder, append and execute
//	method indexing under the object's own type and refusing, rather than truncating, an index the type cannot hold.  the
//	default is 16-bit, so an earlier caller's behaviour is unchanged but where it was a defect, of which there were two.
//	an encode or append that would take a 16-bit object past 65,535 vertexes, which under 1 answered YES with its indexes
//	wrapped (65,535 itself reading as a restart), answers NO with nothing written.  and a filled arc drawn as points,
//	lines or separate triangles, which under 1 reserved one index it never wrote (points, lines) or wrote indexes past
//	those it reserved and, for less than a whole circle, named vertexes it never added (triangles), writes exactly the
//	indexes its count reserves and names only the vertexes it adds.
//	3 is VVMTLPool's idle lifetime: the 'idleLifetime' property, 2 seconds by default, is how long an item may sit
//	idle in the pool, in seconds of the pool's host-time clock, before -housekeeping deletes it, where under 1 and 2
//	an item was deleted by the first -housekeeping call after the thirty it had sat through, whatever the time those
//	calls took; the pool hands out what it holds first in, first out, where under 1 and 2 a request took the item
//	given back most recently; and VVMTLRecycleable's 'pooledSince', the host-clock time an item was given back, which
//	is 0 on any item a client holds, replaces 'recycleCount', its count of calls, which nothing outside the pool read.
//	no caller needs either of 2's defects, and nothing outside VVMetalKit reads 'idleLifetime', 'pooledSince' or the
//	old 'recycleCount', so DYLIB_COMPATIBILITY_VERSION stays at 1: a copy at 1 runs every caller, with the defects 2
//	mends and a pool that ages by calls and hands out last in, first out.
//	4 is CopierMTLScene's sizing and VVMTLUtilities' read-back.  the copier places the source's srcRect in the
//	destination by the SizingMode it is given, snapped to whole pixels, and writes every pixel outside it transparent
//	black, where under 1 to 3 it stretched every copy over the whole destination whatever the mode; its stored
//	'allowScaling', which nothing read, is gone, the argument still refusing a copy between different sizes.
//	CreateCGImageRefFromResizedMTLTexture returns an image of the size asked for, the texture fitted into it, where
//	under 1 to 3 it returned the texture's own size, and answers NULL for a size that rounds to no pixels;
//	CreateCGImageRefFromResizedVVMTLTextureImage fits rather than stretches, answers NULL likewise, and for an image
//	whose srcRect is already the size asked for but not its whole texture gives its srcRect, where under 1 to 3 it gave
//	the whole texture.  and CreateCGImageRefFromMTLTexture, which every CGImage path reads through, synchronizes a
//	managed texture before reading it, where under 1 to 3 it read a managed texture's CPU copy unsynchronized, stale on
//	a discrete GPU; tags every image it makes premultiplied, the alpha of the output it reads, where under 1 to 3 it
//	tagged them straight, so that every premultiplied pixel that was not opaque composited wrongly; makes an RGBA16Uint
//	texture an 8-bit image, where under 1 to 3 it declared 16 bits a component over 8-bit bytes and made no image; and
//	releases its colour space once for the once it creates it, where under 1 to 3 it retained it once more, which leaked
//	nothing because the named sRGB space is immortal.  the signatures are unchanged and a copy at 1 runs every caller,
//	with the defects 4 mends, so DYLIB_COMPATIBILITY_VERSION stays at 1.
FOUNDATION_EXPORT const NSInteger VVMetalKitAPIVersion;

#import <Metal/Metal.h>

#import <VVMetalKit/RenderProperties.h>
#import <VVMetalKit/SwizzleMTLScene.h>
#import <VVMetalKit/CopierMTLScene.h>
#import <VVMetalKit/CustomMetalView.h>
#import <VVMetalKit/CMVMTLDrawObject.h>
#import <VVMetalKit/CMVMTLDrawObjectScene.h>
#import <VVMetalKit/CMVMTLDrawObjectView.h>

#include <VVMetalKit/SizingToolTypes.h>
//#import <VVMetalKit/VVSizingTool.h>
//#import <VVMetalKit/SizingTool_c.h>
#import <VVMetalKit/SizingTool_objc.h>
//#import <VVMetalKit/SizingTool_metal.h>
#import <VVMetalKit/SwizzleMTLScene.h>
#import <VVMetalKit/VVColorConversions.h>
#import <VVMetalKit/BilinearInterpolation.h>
#import <VVMetalKit/BicubicInterpolation.h>

#import <VVMetalKit/VVMTLTimestamp.h>
#import <VVMetalKit/VVMTLImage.h>
#import <VVMetalKit/VVMTLLUT.h>
#import <VVMetalKit/VVMTLRecycleable.h>
#import <VVMetalKit/VVMTLRecycleableDescriptor.h>
#import <VVMetalKit/VVMTLRecyclingPool.h>
#import <VVMetalKit/VVMTLBuffer.h>
#import <VVMetalKit/VVMTLBufferDescriptor.h>
#import <VVMetalKit/VVMTLTextureImage.h>
#import <VVMetalKit/VVMTLTextureImageDescriptor.h>
#import <VVMetalKit/VVMTLTextureLUT.h>
#import <VVMetalKit/VVMTLTextureLUTDescriptor.h>
#import <VVMetalKit/VVMTLSurfaceImage.h>
#import <VVMetalKit/VVMTLSurfaceImageDescriptor.h>
#import <VVMetalKit/VVMTLSurfaceImage+Swizzle.h>
#import <VVMetalKit/VVMTLPool.h>

#import <VVMetalKit/VVMTLScene.h>
#import <VVMetalKit/VVMTLComputeScene.h>
#import <VVMetalKit/VVMTLRenderScene.h>
#import <VVMetalKit/VVMTLOrthoRenderScene.h>
#import <VVMetalKit/VVMTLPerspRenderScene.h>

#import <VVMetalKit/VVMTLTextureImageRectView.h>
#import <VVMetalKit/VVMTLTextureImageView.h>
#import <VVMetalKit/VVMTLTextureImageRectViewShaderTypes.h>
#import <VVMetalKit/VVMTLTextureImageShaderTypes.h>

#import <VVMetalKit/VVMTLUtilities.h>
#import <VVMetalKit/AAPLMathUtilities.h>
#import <VVMetalKit/CIImageAdditions.h>
#import <VVMetalKit/CIMTLScene.h>



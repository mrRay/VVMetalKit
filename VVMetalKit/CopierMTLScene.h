#import <Foundation/Foundation.h>

#import <VVMetalKit/VVMTLComputeScene.h>
//#import <VVMetalKit/VVSizingTool.h>
#import <VVMetalKit/SizingToolTypes.h>

NS_ASSUME_NONNULL_BEGIN




///	Class that uses a Metal compute encoder to copy the contents of one image to another.
///	Other methods of copying textures- such as a blit encoder- may be more performant, but are more stringent and may not work under all circumstances.




@interface CopierMTLScene : VVMTLComputeScene

///	Copies the contents of one image to another, optionally performing scaling/resizing.  The 'srcRect' property of the passed image is respected during the copy.
///	The source's srcRect is placed in the whole of the destination texture by 'inSM', as RectThatFitsRectInRect() places one rect in another, with the placed rect's edges snapped to the nearest pixel: Fit may letter- or pillarbox, FitWidth may letterbox or crop above and below, Fill may crop, Stretch covers the destination, and Copy centres the source at its own size, cropping it where it is larger.  Every destination pixel outside the placed rect is written transparent black (0,0,0,0), and a placed rect one pixel wide or high samples the middle of the srcRect across that span.
///	If 'inScale' is NO, the source's srcRect must be exactly the destination's size, and a copy between different sizes is refused with an error logged and nothing encoded; at equal sizes every mode places the source over the whole destination.
- (void) copyImg:(id<VVMTLTextureImage>)inSrc toImg:(id<VVMTLTextureImage>)inDst allowScaling:(BOOL)inScale sizingMode:(SizingMode)inSM inCommandBuffer:(id<MTLCommandBuffer>)inCB;

@end




NS_ASSUME_NONNULL_END

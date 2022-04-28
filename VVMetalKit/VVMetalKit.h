#import <Foundation/Foundation.h>

//! Project version number for VVMetalKit.
FOUNDATION_EXPORT double VVMetalKitVersionNumber;

//! Project version string for VVMetalKit.
FOUNDATION_EXPORT const unsigned char VVMetalKitVersionString[];

#import <Metal/Metal.h>

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <VVMetalKitTouch/RenderProperties.h>
#import <VVMetalKitTouch/MTLImgBufferShaderTypes.h>
#import <VVMetalKitTouch/MTLImgBuffer.h>
#import <VVMetalKitTouch/MTLPool.h>
#import <VVMetalKitTouch/MTLScene.h>
#import <VVMetalKitTouch/MTLComputeScene.h>
#import <VVMetalKitTouch/MTLRenderScene.h>
#import <VVMetalKitTouch/SwizzleMTLScene.h>
#import <VVMetalKitTouch/CopierMTLScene.h>
#import <VVMetalKitTouch/CustomMetalView.h>
#import <VVMetalKitTouch/MTLImgBufferView.h>
#import <VVMetalKitTouch/MTLImgBufferViewShaderTypes.h>
#import <VVMetalKitTouch/VVSizingTool.h>
#import <VVMetalKitTouch/SizingTool_c.h>
#import <VVMetalKitTouch/SizingTool_objc.h>
#import <VVMetalKitTouch/SizingTool_Metal.h>
#import <VVMetalKitTouch/SwizzleMTLScene.h>
#import <VVMetalKitTouch/VVColorConversions.h>
#import <VVMetalKitTouch/BilinearInterpolation.h>
#import <VVMetalKitTouch/BicubicInterpolation.h>

#else

#import <VVMetalKit/RenderProperties.h>
#import <VVMetalKit/MTLImgBufferShaderTypes.h>
#import <VVMetalKit/MTLImgBuffer.h>
#import <VVMetalKit/MTLPool.h>
#import <VVMetalKit/MTLScene.h>
#import <VVMetalKit/MTLComputeScene.h>
#import <VVMetalKit/MTLRenderScene.h>
#import <VVMetalKit/SwizzleMTLScene.h>
#import <VVMetalKit/CopierMTLScene.h>
#import <VVMetalKit/CustomMetalView.h>
#import <VVMetalKit/MTLImgBufferView.h>
#import <VVMetalKit/MTLImgBufferViewShaderTypes.h>
#import <VVMetalKit/VVSizingTool.h>
#import <VVMetalKit/SizingTool_c.h>
#import <VVMetalKit/SizingTool_objc.h>
#import <VVMetalKit/SizingTool_Metal.h>
#import <VVMetalKit/SwizzleMTLScene.h>
#import <VVMetalKit/VVColorConversions.h>
#import <VVMetalKit/BilinearInterpolation.h>
#import <VVMetalKit/BicubicInterpolation.h>

#endif


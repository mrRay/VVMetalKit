#if defined(TARGET_OS_IOS) && TARGET_OS_IOS==1
#import <UIKit/UIKit.h>
#import <VVMetalKitTouch/MTLImgBufferRectView.h>
#else
#import <Cocoa/Cocoa.h>
#import <VVMetalKit/MTLImgBufferRectView.h>
#endif

NS_ASSUME_NONNULL_BEGIN




@interface MTLImgBufferView : MTLImgBufferRectView
@end




NS_ASSUME_NONNULL_END

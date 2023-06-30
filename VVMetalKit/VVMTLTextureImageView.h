//
//  VVMTLTextureImageView.h
//  VVMetalKit
//
//  Created by testadmin on 6/29/23.
//

#if defined(TARGET_OS_IOS) && TARGET_OS_IOS==1
#import <UIKit/UIKit.h>
#import <VVMetalKitTouch/VVMTLTextureImageRectView.h>
#else
#import <Cocoa/Cocoa.h>
#import <VVMetalKit/VVMTLTextureImageRectView.h>
#endif

NS_ASSUME_NONNULL_BEGIN




@interface VVMTLTextureImageView : VVMTLTextureImageRectView
@end




NS_ASSUME_NONNULL_END

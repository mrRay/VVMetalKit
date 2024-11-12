//
//  VVMTLPerspRenderScene.h
//  VVMetalKit
//
//  Created by testadmin on 10/8/24.
//


#import <VVMetalKit/VVMTLRenderScene.h>

NS_ASSUME_NONNULL_BEGIN




/*		Intended to provide a simple base class for performing perspective (non-orthographic) rendering. Don't do much of this, but it's handy when I need it!
		- Basically, this class just populates its superclass' "mvpBuffer" property with a 4x4 single-precision floating-point matrix that contains the cumulative model/view/projection matrix transform
		- YOU STILL NEED TO APPLY THE MVP BUFFER TO YOUR RENDER ENCODER
*/




@interface VVMTLPerspRenderScene : VVMTLRenderScene

@end




NS_ASSUME_NONNULL_END

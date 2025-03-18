//
//  VVMTLTextureImageView.h
//  VVMetalKit
//
//  Created by testadmin on 6/29/23.
//

#import <Cocoa/Cocoa.h>
#import <VVMetalKit/VVMTLTextureImageRectView.h>

NS_ASSUME_NONNULL_BEGIN




/**		If you want to draw an id<VVMTLTextureImage> as big as possible (without cropping) with Metal, use this class
		- Assign a texture to its 'imgBuffer' property
		- Call `-[VVMTLTextureImageView drawInCmdBuffer:]` to perform drawing
*/




@interface VVMTLTextureImageView : VVMTLTextureImageRectView
@end




NS_ASSUME_NONNULL_END

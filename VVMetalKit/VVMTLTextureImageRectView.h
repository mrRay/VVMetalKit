//
//  VVMTLTextureImageRectView.h
//  VVMetalKit
//
//  Created by testadmin on 6/29/23.
//

#import <Cocoa/Cocoa.h>
#import <VVMetalKit/CustomMetalView.h>
#import <VVMetalKit/VVMTLTextureImage.h>
#import <VVMetalKit/VVMTLPool.h>

NS_ASSUME_NONNULL_BEGIN




/*		base class that draws the 'srcRect' region of its 'imgBuffer' property inside 'vertRect'.
*/




@interface VVMTLTextureImageRectView : CustomMetalView

//	buffer of the vertices that are drawn
@property (strong,nullable) id<MTLBuffer> vertBuffer;
//	buffer containing the model/view/projection matrices that control display
@property (strong,nullable) id<MTLBuffer> mvpBuffer;
//	buffer containing the src rect and anamorphic ratio of the images we're asked to display
@property (strong,nullable) id<VVMTLBuffer> geoBuffer;

//	texture containing the image we want to draw.  the area of the image in the VVMTLTextureImage's 'srcRect' will be drawn within the receiver's 'vertRect'.
@property (strong,nullable,atomic) id<VVMTLTextureImage> imgBuffer;

//	a label that appears in command buffers and NSLog()
@property (strong,nullable) NSString * label;

//	NON-normalized (pixel coords), origin is top-left corner of rendering context.  user is responsible for updating this in response to changes in the window dimensions.  quad draws in this rect.
@property (readwrite) NSRect vertRect;

//	if nil, no tint will be applied (tint color will be 1,1,1,1)
@property (strong) NSColor * imgTint;


@end




NS_ASSUME_NONNULL_END


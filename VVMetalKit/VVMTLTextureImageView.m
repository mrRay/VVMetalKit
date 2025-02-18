//
//  VVMTLTextureImageView.m
//  VVMetalKit
//
//  Created by testadmin on 6/29/23.
//

#import "VVMTLTextureImageView.h"
//#import "TargetConditionals.h"
//#import "VVMTLTextureImageRectViewShaderTypes.h"
//#import "RenderProperties.h"
//#import "VVSizingTool.h"
//#import "SizingTool_c.h"
#import "SizingTool_objc.h"




@implementation VVMTLTextureImageView


- (void) setImgBuffer:(id<VVMTLTextureImage>)inBuffer	{
	//NSLog(@"%s ... %@",__func__,inBuffer);
	self.vertRect = NSRectThatFitsRectInRect(inBuffer.srcRect, NSMakeRect(0,0,viewportSize.x,viewportSize.y), SizingModeFit);
	[super setImgBuffer:inBuffer];
}

- (BOOL) reconfigureDrawable	{
	BOOL		returnMe = [super reconfigureDrawable];
	if (self.imgBuffer != nil)
		self.vertRect = NSRectThatFitsRectInRect(self.imgBuffer.srcRect, NSMakeRect(0,0,viewportSize.x,viewportSize.y), SizingModeFit);
	return returnMe;
}

- (void) setLayerBackgroundColor:(NSColor *)n	{
	[super setLayerBackgroundColor:n];
	self.layer.backgroundColor = [[NSColor blackColor] CGColor];
}


@end

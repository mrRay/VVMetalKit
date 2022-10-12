#import "MTLImgBufferView.h"
//#import "TargetConditionals.h"
//#import "MTLImgBufferRectViewShaderTypes.h"
//#import "RenderProperties.h"
//#import "VVSizingTool.h"
//#import "SizingTool_c.h"
#import "SizingTool_objc.h"




@implementation MTLImgBufferView


- (void) setImgBuffer:(MTLImgBuffer *)inBuffer	{
	//NSLog(@"%s ... %@",__func__,inBuffer);
	self.vertRect = NSRectThatFitsRectInRect(inBuffer.srcRect, NSMakeRect(0,0,viewportSize.x,viewportSize.y), SizingModeFit);
	[super setImgBuffer:inBuffer];
}


@end

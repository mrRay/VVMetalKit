#import "SwizzleMTLScene.h"




@implementation SwizzleMTLScene


- (nullable instancetype) initWithDevice:(id<MTLDevice>)n	{
	self = [super initWithDevice:n];
	if (self != nil)	{
	}
	return self;
}
- (void) convertSrcImg:(MTLImgBuffer *)inSrcImg srcPixelFormat:(OSType)inSrcPF dstImg:(MTLImgBuffer *)inDstImg dstPixelFormat:(OSType)inDstPF	{
	if (inSrcImg == nil || inDstImg == nil)	{
		NSLog(@"ERR: prereq not met, bailing, %s (%@, %@)",__func__,inSrcImg,inDstImg);
		return;
	}
	
	//switch (inSrcPF)	{
	//}
	//
	//switch (inDstPF)	{
	//}
}


@end

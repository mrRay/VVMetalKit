#import "RenderProperties.h"




NSString * const kRenderPropertiesChangedNotificationName = @"kRenderPropertiesChangedNotificationName";




RenderProperties			*_globalRenderProperties = nil;




@interface RenderProperties ()
@property (strong) id<MTLDevice> device;
@property (strong) id<MTLCommandQueue> renderQueue;
@property (strong) id<MTLCommandQueue> bgCmdQueue;
@end




@implementation RenderProperties


+ (instancetype) global	{
	if (_globalRenderProperties == nil)	{
		@synchronized (self)	{
			if (_globalRenderProperties == nil)
				_globalRenderProperties = [[RenderProperties alloc] init];
		}
	}
	return _globalRenderProperties;
}


- (instancetype) init	{
	self = [super init];
	if (self != nil)	{
		[self configureWithDevice:MTLCreateSystemDefaultDevice()];
	}
	return self;
}


- (void) configureWithDevice:(id<MTLDevice>)n	{
	if (n == nil)
		return;
	
	//@synchronized (self)	{
		self.device = n;
		self.renderQueue = [self.device newCommandQueue];
		self.bgCmdQueue = [self.device newCommandQueue];
	//}
}


@end

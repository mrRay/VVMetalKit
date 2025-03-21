#import "RenderProperties.h"




NSString * const kRenderPropertiesChangedNotificationName = @"kRenderPropertiesChangedNotificationName";




RenderProperties			*_globalRenderProperties = nil;




@interface RenderProperties ()
@property (strong) id<MTLDevice> device;
@property (strong) id<MTLCommandQueue> renderQueue;
@property (strong) id<MTLCommandQueue> bgCmdQueue;
@property (strong) id<MTLCommandQueue> displayCmdQueue;
@property (strong) id<MTLLibrary> defaultLibrary;
@property (assign,readwrite) NSSize max2DTextureSize;
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
		
		CGColorSpaceRef		tmpCS = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
		self.colorSpace = tmpCS;
		CGColorSpaceRelease(tmpCS);
	}
	return self;
}
- (void) dealloc	{
	self.colorSpace = NULL;
}


- (void) configureWithDevice:(id<MTLDevice>)n	{
	if (n == nil)
		return;
	
	//@synchronized (self)	{
		self.device = n;
		self.renderQueue = [self.device newCommandQueue];
		self.bgCmdQueue = [self.device newCommandQueue];
		self.displayCmdQueue = [self.device newCommandQueue];
		
		self.max2DTextureSize = NSMakeSize(16384,16384);
		//[device supportsFamily:MTLGPUFamilyMac2]
		//	maxSize = NSMakeSize(16384,16384);
		//[device supportsFamily:MTLGPUFamilyApple7]
		//[device supportsFamily:MTLGPUFamilyApple8]
		//[device supportsFamily:MTLGPUFamilyApple9]
		//[device supportsFamily:MTLGPUFamilyMetal3]
	//}
}


@synthesize colorSpace=_colorSpace;
- (void) setColorSpace:(CGColorSpaceRef)n	{
	if (_colorSpace != NULL)	{
		CGColorSpaceRelease(_colorSpace);
	}
	_colorSpace = n;
	if (_colorSpace != NULL)	{
		CGColorSpaceRetain(_colorSpace);
	}
}
- (CGColorSpaceRef) colorSpace	{
	return _colorSpace;
}


@end

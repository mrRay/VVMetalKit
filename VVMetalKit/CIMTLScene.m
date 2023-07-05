//
//  CIMTLScene.m
//  VVTestApps
//
//  Created by testadmin on 7/5/23.
//

#import "CIMTLScene.h"

#import "VVMTLScene_priv.h"
#import "VVMTLPool.h"




@interface CIMTLScene ()
@property (strong,readwrite) CIContext * ciContext;
@property (strong,readwrite) CIImage * srcImage;	//	only NON-nil during render callback- freed in cmd buffer's completion handler
@end




@implementation CIMTLScene

- (instancetype) initWithDevice:(id<MTLDevice>)inDevice	{
	self = [super initWithDevice:inDevice];
	if (inDevice == nil)	{
		NSLog(@"ERR: device nil in %s",__func__);
		self = nil;
	}
	if (self != nil)	{
		_ciContext = [CIContext
			contextWithMTLDevice:inDevice
			options:@{
				kCIContextOutputPremultiplied: @( NO ),
				kCIContextPriorityRequestLow: @( NO ),
				//kCIContextWorkingFormat: kCIFormatRGBAf,
				kCIContextOutputColorSpace: [NSNull null],
				kCIContextWorkingColorSpace: [NSNull null],
				//kCIContextOutputColorSpace: CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB),
				//kCIContextWorkingColorSpace: CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB),
				//kCIContextOutputColorSpace: CGColorSpaceCreateWithName(kCGColorSpaceSRGB),
				//kCIContextWorkingColorSpace: CGColorSpaceCreateWithName(kCGColorSpaceSRGB),
				//kCIContextOutputColorSpace: CGColorSpaceCreateWithName(kCGColorSpaceITUR_709),
				//kCIContextWorkingColorSpace: CGColorSpaceCreateWithName(kCGColorSpaceITUR_709),
			}];
	}
	return self;
}


- (void) renderCIImage:(CIImage *)inCIImage toTexture:(id<VVMTLTextureImage>)inTex inCommandBuffer:(id<MTLCommandBuffer>)inCB	{
	if (inTex == nil || inCB == nil)
		return;
	
	_srcImage = inCIImage;
	
	self.renderTarget = inTex;
	self.commandBuffer = inCB;
	
	[self _renderCallback];
	
	self.commandBuffer = nil;
	self.renderTarget = nil;
	
	_srcImage = nil;
}
- (id<VVMTLTextureImage>) renderCIImage:(CIImage *)inCIImage toTextureSized:(NSSize)inSize inCommandBuffer:(id<MTLCommandBuffer>)inCB	{
	if (inCB == nil)
		return nil;
	
	id<VVMTLTextureImage>		returnMe = [VVMTLPool.global bgra8TexSized:inSize];
	[self renderCIImage:inCIImage toTexture:returnMe inCommandBuffer:inCB];
	return returnMe;
}


- (void) renderCallback	{
	CGRect		extent = CGRectZero;
	CIImage		*imageToDraw = _srcImage;
	if (imageToDraw != nil)
		extent = imageToDraw.extent;
	if (CGRectEqualToRect(extent, CGRectZero))
		imageToDraw = nil;
	
	NSError		*nsErr = nil;
	CIRenderDestination		*ciDest = [[CIRenderDestination alloc]
		initWithMTLTexture:self.renderTarget.texture
		commandBuffer:self.commandBuffer];
	CIRenderTask		*renderTask = [_ciContext
		startTaskToRender:imageToDraw
		toDestination:ciDest
		error:&nsErr];
	if (renderTask == nil || nsErr != nil)	{
		NSLog(@"ERR: (%@) in %s",nsErr.localizedDescription,__func__);
	}
	
	[self.commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> completed)	{
		CIImage			*tmpImage = imageToDraw;
		tmpImage = nil;
	}];
	
	imageToDraw = nil;
}

@end

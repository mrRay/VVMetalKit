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
				//kCIContextOutputColorSpace: [NSNull null],
				//kCIContextWorkingColorSpace: [NSNull null],
				kCIContextOutputColorSpace: (__bridge id)self.colorSpace,
				kCIContextWorkingColorSpace: (__bridge id)self.colorSpace,
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


//- (void) setClearColors:(float)r :(float)g :(float)b :(float)a	{
//	MTLRenderPassColorAttachmentDescriptor		*attachDesc = self.renderPassDescriptor.colorAttachments[0];
//	attachDesc.clearColor = MTLClearColorMake(r, g, b, a);
//}


- (void) renderCIImage:(CIImage *)inCIImage toTexture:(id<VVMTLTextureImage>)inTex inCommandBuffer:(id<MTLCommandBuffer>)inCB	{
	if (inTex == nil || inCB == nil)
		return;
	
	//inTex.flipV = YES;
	_srcImage = inCIImage;
	self.renderSize = inTex.srcRect.size;
	
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
	CIImage		*srcImg = _srcImage;
	if (srcImg != nil)
		extent = srcImg.extent;
	if (CGRectEqualToRect(extent, CGRectZero))
		srcImg = nil;
	//NSLog(@"\t\timage extent is %@",NSStringFromRect(extent));
	
	NSError		*nsErr = nil;
	NSSize		renderSize = self.renderSize;
	/*
	[_ciContext
		render:srcImg
		toMTLTexture:self.renderTarget.texture
		commandBuffer:self.commandBuffer
		//bounds:NSMakeRect(0,0,renderSize.width,renderSize.height)
		bounds:extent
		colorSpace:self.colorSpace];
	*/
	
	CIImage			*bgImg = [CIImage imageWithColor:[CIColor clearColor]];
	CIImage			*imgToDraw = [CIBlendKernel.sourceOver applyWithForeground:srcImg background:bgImg];
	imgToDraw = [imgToDraw imageByCroppingToRect:NSMakeRect(0,0,renderSize.width,renderSize.height)];
	
	CIRenderDestination		*ciDest = [[CIRenderDestination alloc]
		initWithMTLTexture:self.renderTarget.texture
		commandBuffer:self.commandBuffer];
	ciDest.alphaMode = CIRenderDestinationAlphaUnpremultiplied;
	//ciDest.blendKernel = CIBlendKernel.sourceOver;
	ciDest.colorSpace = self.colorSpace;
	//ciDest.clamped = NO;
	//ciDest.dithered = NO;
	ciDest.flipped = YES;
	
	CIRenderTask		*renderTask = [_ciContext
		startTaskToRender:imgToDraw
		toDestination:ciDest
		error:&nsErr];
	if (renderTask == nil || nsErr != nil)	{
		NSLog(@"ERR: (%@) in %s",nsErr.localizedDescription,__func__);
	}
	
	
	[self.commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> completed)	{
		CIImage			*tmpImage = imgToDraw;
		tmpImage = nil;
	}];
	
	srcImg = nil;
}


@end

//
//  VVMTLTextureImage.m
//  VVMetalKit
//
//  Created by testadmin on 6/29/23.
//

#import "VVMTLTextureImage.h"




@interface VVMTLTextureImage ()	{
	IOSurfaceRef		_iosfc;
	CVPixelBufferRef	_cvpb;
}
//	if you use NSCopying to copy a texture/image, this is the original instance from which your copy derives
//	if you make a copy of a copy of a copy or a copy, this will still point to the original texture
//	all copies share the same underlying GPU resource, but may have different extrinsic properties (srcRect, mainly)
@property (strong,readwrite,nullable) VVMTLTextureImage * srcTexImg;
@end




@implementation VVMTLTextureImage

+ (instancetype) createWithDescriptor:(VVMTLTextureImageDescriptor *)n	{
	return [[VVMTLTextureImage alloc] initWithDescriptor:n];
}

- (instancetype) initWithDescriptor:(VVMTLTextureImageDescriptor *)n	{
	self = [super init];
	if (n == nil)
		self = nil;
	if (self != nil)	{
		//	VVMTLTextureImage conformance
		texture = nil;
		
		buffer = nil;
		_iosfc = NULL;
		_cvpb = NULL;
		
		//	VVMTLImage conformance
		width = n.width;
		height = n.height;
		srcRect = NSMakeRect(0,0,width,height);
		flipH = NO;
		flipV = NO;
		
		//	VVMTLTimestamp conformance
		time = kCMTimeZero;
		duration = kCMTimeZero;
		
		//	VVMTLRecycleable conformance
		pool = nil;
		preferDeletion = NO;
		recycleCount = 0;
		descriptor = n;
		supportingObject = nil;
		supportingContext = NULL;
		deletionBlock = nil;
		//deletionBlock = ^(id<VVMTLRecycleable> recycled)	{
		//	VVMTLTextureImage		*recast = (VVMTLTextureImage*)blah;
		//	if (recast == nil)
		//		return;
		//};
	}
	return self;
}

- (void) dealloc	{
	//	if this object wants to be deleted immediately...
	if (preferDeletion)	{
		//	execute the recycle block immediately- we'll free the underlying resources in a sec
		if (deletionBlock != nil)	{
			deletionBlock(self);
		}
	}
	//	else we're NOT deleting the object- we are instead going to recycle it
	else	{
		//	make a copy of myself and pass it back to the pool
		VVMTLTextureImage		*tmpCopy = [self copy];
		
		//	reset the transient properties before we recycle it!
		tmpCopy.srcRect = NSMakeRect(0,0,width,height);
		tmpCopy.flipH = NO;
		tmpCopy.flipV = NO;
		tmpCopy.time = kCMTimeZero;
		tmpCopy.duration = kCMTimeZero;
		
		if (tmpCopy != nil)	{
			[pool recycleObject:tmpCopy];
		}
	}
	
	//	free my underlying resources either way!
	self.iosfc = NULL;
	self.cvpb = nil;
	supportingObject = nil;
	supportingContext = nil;
	deletionBlock = nil;
}

- (BOOL) isVVMTLTextureImage	{
	return YES;
}

#pragma mark - VVMTLTextureImage conformance

@synthesize texture;

@synthesize buffer;
- (void) setIosfc:(IOSurfaceRef)n	{
	if (_iosfc == n)
		return;
	if (_iosfc != NULL)	{
		IOSurfaceDecrementUseCount(_iosfc);
		CFRelease(_iosfc);
		_iosfc = NULL;
	}
	if (n != NULL)	{
		_iosfc = n;
		CFRetain(_iosfc);
		IOSurfaceIncrementUseCount(_iosfc);
	}
}
- (IOSurfaceRef) iosfc	{
	return _iosfc;
}
- (void) setCvpb:(CVPixelBufferRef)n	{
	if (_cvpb == n)
		return;
	if (_cvpb != NULL)	{
		CVPixelBufferRelease(_cvpb);
		_cvpb = NULL;
	}
	if (n != NULL)	{
		CVPixelBufferRetain(n);
		_cvpb = n;
	}
}
- (CVPixelBufferRef) cvpb	{
	return _cvpb;
}

#pragma mark - NSCopying conformance

- (id) copyWithZone:(NSZone *)z	{
	VVMTLTextureImage		*returnMe = [[VVMTLTextureImage alloc] init];
	VVMTLTextureImage		*srcTex = (_srcTexImg != nil) ? _srcTexImg : self;
	
	//	VVMTLTextureImage conformance
	returnMe.texture = srcTex.texture;
	returnMe.buffer = nil;
	returnMe.iosfc = nil;
	returnMe.cvpb = nil;
	returnMe.srcTexImg = srcTex;	//	make sure the copy retains the src!
	
	//	VVMTLImage conformance
	returnMe.width = srcTex.width;
	returnMe.height = srcTex.height;
	returnMe.srcRect = srcTex.srcRect;
	returnMe.flipH = srcTex.flipH;
	returnMe.flipV = srcTex.flipV;
	
	//	VVMTLTimestamp conformance
	returnMe.time = srcTex.time;
	returnMe.duration = srcTex.duration;
	
	//	VVMTLRecycleable conformance
	returnMe.pool = srcTex.pool;
	returnMe.preferDeletion = YES;	//	we just wait to delete the copy immediately (it will retain the original)
	returnMe.recycleCount = 0;
	returnMe.descriptor = [(NSObject*)srcTex.descriptor copy];
	returnMe.supportingObject = nil;	//	do not copy any of the supporting stuff- the original's handling all this.
	returnMe.supportingContext = nil;
	returnMe.deletionBlock = nil;
	
	return returnMe;
}

#pragma mark - VVMTLImage conformance

@synthesize width;
@synthesize height;
@synthesize srcRect;
@synthesize flipH;
@synthesize flipV;

#pragma mark - VVMTLTimestamp conformance

@synthesize time;
@synthesize duration;

- (BOOL) matchesTimestamp:(id<VVMTLTimestamp>)n	{
	if (n == nil)
		return NO;
	if (CMTIME_COMPARE_INLINE(time,!=,n.time)
	|| CMTIME_COMPARE_INLINE(duration,!=,n.duration))
	{
		return NO;
	}
	return YES;
}

#pragma mark - VVMTLRecycleable conformance

@synthesize pool;
@synthesize preferDeletion;
@synthesize recycleCount;
@synthesize descriptor;
@synthesize supportingObject;
@synthesize supportingContext;
@synthesize deletionBlock;

@end








@implementation NSObject (VVMTLTextureImageNSObjectAdditions)
- (BOOL) isVVMTLTextureImage	{
	return NO;
}
@end

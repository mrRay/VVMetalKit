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
		bytesPerRow = n.bytesPerRow;
		
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
		descriptor = [n copy];
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
	//NSLog(@"%s ... %@",__func__,self);
	//	if this object wants to be deleted immediately...
	if (preferDeletion)	{
		//NSLog(@"\t\t%@ prefers deletion...",self);
		//	execute the recycle block immediately- we'll free the underlying resources in a sec
		if (deletionBlock != nil)	{
			deletionBlock(self);
		}
	}
	//	else we're NOT deleting the object- we are instead going to recycle it
	else	{
		//NSLog(@"\t\t%@ prefers recycling...",self);
		//	make a copy of myself- resetting transient properties- and pass it back to the pool
		//VVMTLTextureImage		*tmpCopy = [self copy];	//	NO, do NOT copy like this (it will try to retain the object being copied)
		VVMTLTextureImage		*tmpCopy = [[VVMTLTextureImage alloc] initWithDescriptor:(VVMTLTextureImageDescriptor*)descriptor];
		tmpCopy.texture = texture;
		tmpCopy.buffer = buffer;
		tmpCopy.iosfc = _iosfc;
		tmpCopy.cvpb = _cvpb;
		tmpCopy.bytesPerRow = bytesPerRow;
		
		tmpCopy.width = width;
		tmpCopy.height = height;
		tmpCopy.srcRect = NSMakeRect(0,0,width,height);
		tmpCopy.flipH = NO;
		tmpCopy.flipV = NO;
		
		tmpCopy.time = kCMTimeZero;
		tmpCopy.duration = kCMTimeZero;
		
		tmpCopy.pool = pool;
		tmpCopy.supportingObject = supportingObject;
		tmpCopy.supportingContext = supportingContext;
		tmpCopy.deletionBlock = deletionBlock;
		
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

- (NSString *) description	{
	return [NSString stringWithFormat:@"<%@ %@ %p>", self.className, self.texture.label, self];
}

- (BOOL) isVVMTLTextureImage	{
	return YES;
}

- (BOOL) isEqual:(id)n	{
	if (n == nil)
		return NO;
	if (![(NSObject*)n isVVMTLTextureImage])
		return NO;
	VVMTLTextureImage		*recast = (VVMTLTextureImage *)n;
	
	id<MTLTexture>		tex = texture;
	id<MTLBuffer>		buf = buffer.buffer;
	
	id<MTLTexture>		recastTex = recast.texture;
	id<MTLBuffer>		recastBuf = recast.buffer.buffer;
	
	BOOL			texMatch = ((tex==nil && recastTex==nil) || (tex!=nil && recastTex!=nil && [tex isEqual:recastTex]));
	BOOL			bufferMatch = ((buf==nil && recastBuf==nil) || (buf!=nil && recastBuf!=nil && [buf isEqual:recastBuf]));
	if (!texMatch || !bufferMatch)
		return NO;
	
	return [self.descriptor matchForRecycling:recast.descriptor];
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

@synthesize bytesPerRow;

- (void) populateStruct:(struct VVMTLTextureImageStruct * __nullable)n	{
	if (n==nil)
		return;
	NSRect		tmpRect = self.srcRect;
	n->srcRect.origin.x = round(tmpRect.origin.x);
	n->srcRect.origin.y = round(tmpRect.origin.y);
	n->srcRect.size.width = round(tmpRect.size.width);
	n->srcRect.size.height = round(tmpRect.size.height);
	n->flipV = self.flipV;
	n->flipH = self.flipH;
}

- (CIImage *) createCIImageWithColorSpace:(CGColorSpaceRef)cs	{
	//NSLog(@"%s",__func__);
	NSDictionary		*optsDict = (cs==NULL) ? nil : @{
		kCIImageColorSpace: (__bridge id)cs,
		kCIImageApplyOrientationProperty: @( kCGImagePropertyOrientationDownMirrored )
	};
	
	CIImage			*returnMe = [CIImage
		imageWithMTLTexture:texture
		options:optsDict];
	
	//	if the image needs to be cropped (if srcRect differs from a rect made with the texture dims), do so now
	NSRect			fullFrameRect = NSMakeRect(0,0,width,height);
	if (!NSEqualRects(fullFrameRect,srcRect))	{
		//	the srcRect for VVMTLTextureImage has the origin in the bottom-left corner, but CoreImage's origin is in the top-left corner
		NSPoint			topLeftFullFrame = NSMakePoint(fullFrameRect.origin.x, fullFrameRect.origin.y + fullFrameRect.size.height);
		NSPoint			topLeftSrcRect = NSMakePoint(srcRect.origin.x, srcRect.origin.y + srcRect.size.height);
		NSRect			ciSrcRect;
		ciSrcRect.origin = NSMakePoint(topLeftSrcRect.x - topLeftFullFrame.x, topLeftFullFrame.y - topLeftSrcRect.y);
		ciSrcRect.size = srcRect.size;
		returnMe = [returnMe imageByCroppingToRect:ciSrcRect];
		returnMe = [returnMe imageByApplyingTransform:CGAffineTransformMakeTranslation(-1*ciSrcRect.origin.x, -1*ciSrcRect.origin.y)];
		
		//returnMe = [returnMe imageByCroppingToRect:srcRect];
		//returnMe = [returnMe imageByApplyingTransform:CGAffineTransformMakeTranslation(-1*srcRect.origin.x, -1*srcRect.origin.y)];
	}
	
	BOOL		cumulativeHFlip = flipH;
	BOOL		cumulativeVFlip = flipV;
	cumulativeVFlip = !cumulativeVFlip;	//	no idea why this is necessary, the textures i'm passing it aren't flipped.
	
	if (cumulativeHFlip || cumulativeVFlip)	{
		CGImagePropertyOrientation		newOrientation = 0;
		if (cumulativeHFlip && cumulativeVFlip)	{
			newOrientation = kCGImagePropertyOrientationDown;
		}
		else if (cumulativeVFlip)	{
			newOrientation = kCGImagePropertyOrientationDownMirrored;
		}
		else	{
			newOrientation = kCGImagePropertyOrientationUpMirrored;
		}
		returnMe = [returnMe imageByApplyingCGOrientation:newOrientation];
	}
	
	return returnMe;
}

#pragma mark - NSCopying conformance

- (id) copyWithZone:(NSZone *)z	{
	VVMTLTextureImage		*returnMe = [[VVMTLTextureImage allocWithZone:z] initWithDescriptor:(VVMTLTextureImageDescriptor*)descriptor];
	VVMTLTextureImage		*srcTex = (_srcTexImg != nil) ? _srcTexImg : self;
	
	//	VVMTLTextureImage conformance
	returnMe.texture = srcTex.texture;
	//returnMe.buffer = nil;
	returnMe.buffer = srcTex.buffer;
	//returnMe.iosfc = nil;
	returnMe.iosfc = srcTex.iosfc;
	//returnMe.cvpb = nil;
	returnMe.cvpb = srcTex.cvpb;
	returnMe.bytesPerRow = bytesPerRow;
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
- (NSSize) size	{
	return NSMakeSize(width,height);
}
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

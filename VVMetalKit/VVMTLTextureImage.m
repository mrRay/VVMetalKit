//
//  VVMTLTextureImage.m
//  VVMetalKit
//
//  Created by testadmin on 6/29/23.
//

#import "VVMTLTextureImage.h"

#import "VVMacros.h"




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
		_srcTexImg = nil;
		
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
		_supportingObject = nil;
		_supportingContext = NULL;
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
	if (preferDeletion || pool == nil)	{
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
		tmpCopy.supportingObject = self.supportingObject;
		tmpCopy.supportingContext = self.supportingContext;
		tmpCopy.deletionBlock = deletionBlock;
		
		if (tmpCopy != nil)	{
			[pool recycleObject:tmpCopy];
		}
	}
	
	//	free my underlying resources either way!
	self.iosfc = NULL;
	self.cvpb = nil;
	self.supportingObject = nil;
	self.supportingContext = nil;
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

- (NSRect) mtlSrcRect	{
	NSRect		returnMe = self.srcRect;
	//	get the top-left corner of the existing src rect
	NSPoint		topLeftCornerInBottomLeftSystem = VVRectGetAnchorPoint(self.srcRect, VVRectAnchor_TL);
	//	conver it to the bottom-left of the new src rect
	returnMe.origin.y = self.height - topLeftCornerInBottomLeftSystem.y;
	return returnMe;
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
	n->srcRectCart.origin.x = round(tmpRect.origin.x);
	n->srcRectCart.origin.y = round(tmpRect.origin.y);
	n->srcRectCart.size.width = round(tmpRect.size.width);
	n->srcRectCart.size.height = round(tmpRect.size.height);
	
	NSRect		texBounds = NSMakeRect(0,0,self.width,self.height);
	NSRect		tlRect = ConvertRectBLtoTL(tmpRect, texBounds);
	n->srcRectMtl.origin.x = round(tlRect.origin.x);
	n->srcRectMtl.origin.y = round(tlRect.origin.y);
	n->srcRectMtl.size.width = round(tlRect.size.width);
	n->srcRectMtl.size.height = round(tlRect.size.height);
	
	//n->srcRectMtl.origin.x = n->srcRectCart.origin.x;
	//n->srcRectMtl.size.width = n->srcRectCart.size.width;
	//n->srcRectMtl.size.height = n->srcRectCart.size.height;
	//NSPoint		topLeftCornerCartesian = VVRectGetAnchorPoint(tmpRect, VVRectAnchor_TL);
	//n->srcRectMtl.origin.y = round(self.height - topLeftCornerCartesian.y);
	
	n->flipV = (self.flipV == YES);
	n->flipH = (self.flipH == YES);
}

- (CIImage *) createCIImageWithColorSpace:(CGColorSpaceRef)cs	{
	//NSLog(@"%s",__func__);
	CGImagePropertyOrientation		orientation = self.CIImagePropertyOrientation;
	NSMutableDictionary		*optsDict = [NSMutableDictionary dictionaryWithCapacity:0];
	if (cs != NULL)	{
		optsDict[kCIImageColorSpace] = (__bridge id)cs;
	}
	optsDict[kCIImageApplyOrientationProperty] = @( orientation );
	
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
	
	returnMe = [returnMe imageByApplyingCGOrientation:orientation];
	
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
	//returnMe.supportingObject = nil;	//	do not copy any of the supporting stuff- the original's handling all this.
	//returnMe.supportingContext = nil;
	returnMe.deletionBlock = nil;
	
	srcTex = nil;
	
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
- (CGImagePropertyOrientation) cgImagePropertyOrientation	{
	if (self.flipH)	{
		if (self.flipV)	{
			return kCGImagePropertyOrientationDown;
		}
		else	{
			return kCGImagePropertyOrientationUpMirrored;
		}
	}
	else	{
		if (self.flipV)	{
			return kCGImagePropertyOrientationDownMirrored;
		}
		else	{
			return kCGImagePropertyOrientationUp;
		}
	}
}
- (CGImagePropertyOrientation) CIImagePropertyOrientation	{
	if (self.flipH)	{
		if (self.flipV)	{
			return kCGImagePropertyOrientationUpMirrored;
		}
		else	{
			return kCGImagePropertyOrientationDown;
		}
	}
	else	{
		if (self.flipV)	{
			return kCGImagePropertyOrientationUp;
		}
		else	{
			return kCGImagePropertyOrientationDownMirrored;
		}
	}
}

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
@synthesize supportingObject=_supportingObject;
- (void) setSupportingObject:(id)n	{
	//	we only want the supporting object and context to be attached/retained by the single base instance- we don't want any of its copies to also retain the object/context...
	if (_srcTexImg == nil)	{
		_supportingObject = n;
		return;
	}
	else	{
		//	commented out because this should arguably be unintended- no object should really be screwing with the source texture's supporting context or object...right?
		//_srcTexImg.supportingObject = n;
	}
}
- (id) supportingObject:(id)n	{
	if (_srcTexImg == nil)	{
		return _supportingObject;
	}
	else	{
		return _srcTexImg.supportingObject;
	}
}
@synthesize supportingContext=_supportingContext;
- (void) setSupportingContext:(void *)n	{
	//	we only want the supporting object and context to be attached/retained by the single base instance- we don't want any of its copies to also retain the object/context...
	if (_srcTexImg == nil)	{
		_supportingContext = n;
		return;
	}
	else	{
		//	commented out because this should arguably be unintended- no object should really be screwing with the source texture's supporting context or object...right?
		//_srcTexImg.supportingContext = n;
	}
}
- (void *) supportingContext	{
	if (_srcTexImg == nil)	{
		return _supportingContext;
	}
	else	{
		return _srcTexImg.supportingContext;
	}
}
@synthesize deletionBlock;

@end








@implementation NSObject (VVMTLTextureImageNSObjectAdditions)
- (BOOL) isVVMTLTextureImage	{
	return NO;
}
@end

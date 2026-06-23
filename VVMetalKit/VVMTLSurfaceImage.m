//
//  VVMTLSurfaceImage.m
//  VVMetalKit
//
//  Created by testadmin on 6/22/26.
//

#import "VVMTLSurfaceImage.h"




@interface VVMTLSurfaceImage ()	{
	CVPixelBufferRef	_cvpb;
	IOSurfaceRef		_iosfc;
	//	cached per-plane geometry (read independently per plane from the IOSurface)
	NSUInteger			_planeOffsets[VVMTLSURFACEIMAGE_MAX_PLANES];
	NSUInteger			_planeBytesPerRows[VVMTLSURFACEIMAGE_MAX_PLANES];
	NSUInteger			_planeWidths[VVMTLSURFACEIMAGE_MAX_PLANES];
	NSUInteger			_planeHeights[VVMTLSURFACEIMAGE_MAX_PLANES];
}
@end




@implementation VVMTLSurfaceImage

+ (instancetype) createWithDescriptor:(VVMTLSurfaceImageDescriptor *)n	{
	return [[VVMTLSurfaceImage alloc] initWithDescriptor:n];
}

- (instancetype) initWithDescriptor:(VVMTLSurfaceImageDescriptor *)n	{
	self = [super init];
	if (n == nil)
		self = nil;
	if (self != nil)	{
		//	VVMTLSurfaceImage conformance
		_cvpb = NULL;
		_iosfc = NULL;
		wholeSurfaceBuffer = nil;
		planeCount = 0;
		for (NSUInteger i=0; i<VVMTLSURFACEIMAGE_MAX_PLANES; ++i)	{
			_planeOffsets[i] = 0;
			_planeBytesPerRows[i] = 0;
			_planeWidths[i] = 0;
			_planeHeights[i] = 0;
		}

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
	}
	return self;
}

- (void) dealloc	{
	//	if this object wants to be deleted immediately...
	if (preferDeletion || pool == nil)	{
		//	execute the recycle block immediately- we'll free the underlying resources in a sec
		if (deletionBlock != nil)	{
			deletionBlock(self);
		}
	}
	//	else we're NOT deleting the object- we are instead going to recycle it
	else	{
		//	make a copy of myself- resetting transient properties- and pass it back to the pool.
		//	the copy takes its OWN refs to the cvpb/iosfc/buffer (via the setters / strong assign) BEFORE 'self' releases them below, so the surface's refcount never hits zero mid-handoff.
		VVMTLSurfaceImage		*tmpCopy = [[VVMTLSurfaceImage alloc] initWithDescriptor:(VVMTLSurfaceImageDescriptor*)descriptor];
		tmpCopy.cvpb = _cvpb;	//	setter does CVPixelBufferRetain
		tmpCopy.iosfc = _iosfc;	//	setter does CFRetain + IOSurfaceIncrementUseCount
		tmpCopy.wholeSurfaceBuffer = wholeSurfaceBuffer;	//	strong ref carried forward (the same no-copy buffer aliasing the surface)
		[tmpCopy setPlaneCount:planeCount offsets:_planeOffsets bytesPerRows:_planeBytesPerRows widths:_planeWidths heights:_planeHeights];

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
	self.cvpb = NULL;
	wholeSurfaceBuffer = nil;
	self.supportingObject = nil;
	self.supportingContext = nil;
	deletionBlock = nil;
}

- (NSString *) description	{
	return [NSString stringWithFormat:@"<%@ %ldx%ld %p>", self.className, (unsigned long)width, (unsigned long)height, self];
}

- (BOOL) isVVMTLSurfaceImage	{
	return YES;
}

- (BOOL) isEqual:(id)n	{
	if (n == nil)
		return NO;
	if (![(NSObject*)n isVVMTLSurfaceImage])
		return NO;
	VVMTLSurfaceImage		*recast = (VVMTLSurfaceImage *)n;

	CVPixelBufferRef		recastCVPB = recast.cvpb;
	BOOL			cvpbMatch = ((_cvpb==NULL && recastCVPB==NULL) || (_cvpb!=NULL && recastCVPB!=NULL && _cvpb==recastCVPB));
	if (!cvpbMatch)
		return NO;

	return [self.descriptor matchForRecycling:recast.descriptor];
}

#pragma mark - VVMTLSurfaceImage conformance

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

@synthesize wholeSurfaceBuffer;
@synthesize planeCount;

- (NSUInteger) bytesPerRowOfPlane:(NSUInteger)inPlaneIdx	{
	if (inPlaneIdx >= planeCount || inPlaneIdx >= VVMTLSURFACEIMAGE_MAX_PLANES)
		return 0;
	return _planeBytesPerRows[inPlaneIdx];
}
- (NSUInteger) offsetOfPlane:(NSUInteger)inPlaneIdx	{
	if (inPlaneIdx >= planeCount || inPlaneIdx >= VVMTLSURFACEIMAGE_MAX_PLANES)
		return 0;
	return _planeOffsets[inPlaneIdx];
}
- (NSUInteger) widthOfPlane:(NSUInteger)inPlaneIdx	{
	if (inPlaneIdx >= planeCount || inPlaneIdx >= VVMTLSURFACEIMAGE_MAX_PLANES)
		return 0;
	return _planeWidths[inPlaneIdx];
}
- (NSUInteger) heightOfPlane:(NSUInteger)inPlaneIdx	{
	if (inPlaneIdx >= planeCount || inPlaneIdx >= VVMTLSURFACEIMAGE_MAX_PLANES)
		return 0;
	return _planeHeights[inPlaneIdx];
}

- (void) setPlaneCount:(NSUInteger)inPlaneCount offsets:(const NSUInteger *)inOffsets bytesPerRows:(const NSUInteger *)inBytesPerRows widths:(const NSUInteger *)inWidths heights:(const NSUInteger *)inHeights	{
	NSUInteger		cappedCount = inPlaneCount;
	if (cappedCount > VVMTLSURFACEIMAGE_MAX_PLANES)
		cappedCount = VVMTLSURFACEIMAGE_MAX_PLANES;
	planeCount = cappedCount;
	for (NSUInteger i=0; i<cappedCount; ++i)	{
		_planeOffsets[i] = (inOffsets != NULL) ? inOffsets[i] : 0;
		_planeBytesPerRows[i] = (inBytesPerRows != NULL) ? inBytesPerRows[i] : 0;
		_planeWidths[i] = (inWidths != NULL) ? inWidths[i] : 0;
		_planeHeights[i] = (inHeights != NULL) ? inHeights[i] : 0;
	}
	for (NSUInteger i=cappedCount; i<VVMTLSURFACEIMAGE_MAX_PLANES; ++i)	{
		_planeOffsets[i] = 0;
		_planeBytesPerRows[i] = 0;
		_planeWidths[i] = 0;
		_planeHeights[i] = 0;
	}
}

#pragma mark - NSCopying conformance

- (id) copyWithZone:(NSZone *)z	{
	VVMTLSurfaceImage		*returnMe = [[VVMTLSurfaceImage allocWithZone:z] initWithDescriptor:(VVMTLSurfaceImageDescriptor*)descriptor];

	//	all copies share the same underlying surface- the copy takes its own refs (setters/strong assign)
	returnMe.cvpb = _cvpb;
	returnMe.iosfc = _iosfc;
	returnMe.wholeSurfaceBuffer = wholeSurfaceBuffer;
	[returnMe setPlaneCount:planeCount offsets:_planeOffsets bytesPerRows:_planeBytesPerRows widths:_planeWidths heights:_planeHeights];

	//	VVMTLImage conformance
	returnMe.width = width;
	returnMe.height = height;
	returnMe.srcRect = srcRect;
	returnMe.flipH = flipH;
	returnMe.flipV = flipV;

	//	VVMTLTimestamp conformance
	returnMe.time = time;
	returnMe.duration = duration;

	//	VVMTLRecycleable conformance
	returnMe.pool = pool;
	returnMe.preferDeletion = YES;	//	delete the copy immediately on release (it took its own refs above)
	returnMe.recycleCount = 0;
	returnMe.descriptor = [(NSObject*)descriptor copy];
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
@synthesize supportingContext=_supportingContext;
@synthesize deletionBlock;

@end




@implementation NSObject (VVMTLSurfaceImageNSObjectAdditions)
- (BOOL) isVVMTLSurfaceImage	{
	return NO;
}
@end

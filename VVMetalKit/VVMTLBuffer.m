//
//  VVMTLBuffer.m
//  VVMetalKit
//
//  Created by testadmin on 6/29/23.
//

#import "VVMTLBuffer.h"




@interface VVMTLBuffer ()
//	if you use NSCopying to copy a buffer/image, this is the original instance from which your copy derives
//	if you make a copy of a copy of a copy or a copy, this will still point to the original buffer
//	all copies share the same underlying GPU resource, but may have different extrinsic properties (srcRect, mainly)
@property (strong,readwrite,nullable) VVMTLBuffer * srcBuffer;
@end




@implementation VVMTLBuffer

+ (instancetype) createWithDescriptor:(VVMTLBufferDescriptor *)n	{
	return [[VVMTLBuffer alloc] initWithDescriptor:n];
}

- (instancetype) initWithDescriptor:(VVMTLBufferDescriptor *)n	{
	self = [super init];
	if (n == nil)
		self = nil;
	if (self != nil)	{
		//	VVMTLBuffer conformance
		buffer = nil;
		
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
		//	VVMTLBuffer		*recast = (VVMTLBuffer*)blah;
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
		VVMTLBuffer		*tmpCopy = [self copy];
		if (tmpCopy != nil)	{
			[pool recycleObject:tmpCopy];
		}
	}
	
	//	free my underlying resources either way!
	supportingObject = nil;
	supportingContext = nil;
	deletionBlock = nil;
}
- (BOOL) isVVMTLBuffer	{
	return YES;
}

#pragma mark - VVMTLBuffer conformance

@synthesize buffer;

#pragma mark - NSCopying conformance

- (id) copyWithZone:(NSZone *)z	{
	VVMTLBuffer		*returnMe = [[VVMTLBuffer alloc] init];
	VVMTLBuffer		*srcBuffer = (_srcBuffer != nil) ? _srcBuffer : self;
	
	//	VVMTLBuffer conformance
	returnMe.buffer = srcBuffer.buffer;
	
	//	VVMTLImage conformance
	//returnMe.width = srcBuffer.width;
	//returnMe.height = srcBuffer.height;
	//returnMe.srcRect = srcBuffer.srcRect;
	//returnMe.flipH = srcBuffer.flipH;
	//returnMe.flipV = srcBuffer.flipV;
	
	//	VVMTLTimestamp conformance
	returnMe.time = srcBuffer.time;
	returnMe.duration = srcBuffer.duration;
	
	//	VVMTLRecycleable conformance
	returnMe.pool = srcBuffer.pool;
	returnMe.preferDeletion = YES;	//	we just wait to delete the copy immediately (it will retain the original)
	returnMe.recycleCount = 0;
	returnMe.descriptor = [(NSObject*)srcBuffer.descriptor copy];
	returnMe.supportingObject = nil;	//	do not copy any of the supporting stuff- the original's handling all this.
	returnMe.supportingContext = nil;
	returnMe.deletionBlock = nil;
	
	return returnMe;
}

//#pragma mark - VVMTLImage conformance
//
//@synthesize width;
//@synthesize height;
//@synthesize srcRect;
//@synthesize flipH;
//@synthesize flipV;

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








@implementation NSObject (VVMTLBufferNSObjectAdditions)
- (BOOL) isVVMTLBuffer	{
	return NO;
}
@end

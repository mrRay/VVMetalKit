//
//  VVMTLTextureLUTDescriptor.m
//  VVMetalKit
//
//  Created by testadmin on 7/12/23.
//

#import "VVMTLTextureLUTDescriptor.h"




@implementation VVMTLTextureLUTDescriptor


+ (instancetype) createWithOrder:(uint8_t)inOrder size:(MTLSize)inSize pixelFormat:(MTLPixelFormat)inPfmt storage:(MTLStorageMode)inStorage usage:(MTLTextureUsage)inUsage	{
	return [[VVMTLTextureLUTDescriptor alloc] initWithOrder:inOrder size:inSize pixelFormat:inPfmt storage:inStorage usage:inUsage];
}

- (instancetype) initWithOrder:(uint8_t)inOrder size:(MTLSize)inSize pixelFormat:(MTLPixelFormat)inPfmt storage:(MTLStorageMode)inStorage usage:(MTLTextureUsage)inUsage	{
	self = [super init];
	if (self != nil)	{
		_order = inOrder;
		_size = inSize;
		_pfmt = inPfmt;
		_storage = inStorage;
		_usage = inUsage;
		_mtlBufferBacking = NO;
	}
	return self;
}

- (BOOL) isVVMTLTextureLUTDescriptor	{
	return YES;
}


#pragma mark - NSCopying conformance


- (id) copyWithZone:(NSZone *)z	{
	VVMTLTextureLUTDescriptor		*returnMe = [[VVMTLTextureLUTDescriptor alloc] init];
	returnMe.order = _order;
	returnMe.size = _size;
	returnMe.pfmt = _pfmt;
	returnMe.storage = _storage;
	returnMe.usage = _usage;
	returnMe.mtlBufferBacking = _mtlBufferBacking;
	return returnMe;
}


#pragma mark - VVMTLRecycleableDescriptor conformance


- (BOOL) matchForRecycling:(id<VVMTLRecycleableDescriptor>)n	{
	if (n == nil || ![(NSObject*)n isVVMTLTextureLUTDescriptor])
		return NO;
	VVMTLTextureLUTDescriptor		*recast = (VVMTLTextureLUTDescriptor *)n;
	MTLSize		recastSize = recast.size;
	if (_order != recast.order
	|| _size.width != recastSize.width
	|| _size.height != recastSize.height
	|| _size.depth != recastSize.depth
	|| _pfmt != recast.pfmt
	|| _storage != recast.storage
	|| _usage != recast.usage
	|| _mtlBufferBacking != recast.mtlBufferBacking)
	{
		return NO;
	}
	
	return YES;
}


@end




@implementation NSObject (VVMTLTextureLUTDescriptorNSObjectAdditions)
- (BOOL) isVVMTLTextureLUTDescriptor	{
	return NO;
}
@end

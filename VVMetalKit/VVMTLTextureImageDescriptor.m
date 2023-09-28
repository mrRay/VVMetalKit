//
//  VVMTLTextureImageDescriptor.m
//  VVMetalKit
//
//  Created by testadmin on 6/26/23.
//

#import "VVMTLTextureImageDescriptor.h"




@implementation VVMTLTextureImageDescriptor


+ (instancetype) createWithWidth:(NSUInteger)inWidth height:(NSUInteger)inHeight pixelFormat:(MTLPixelFormat)inPfmt storage:(MTLStorageMode)inStorage usage:(MTLTextureUsage)inUsage bytesPerRow:(NSUInteger)inBytesPerRow	{
	return [[VVMTLTextureImageDescriptor alloc] initWithWidth:inWidth height:inHeight pixelFormat:inPfmt storage:inStorage usage:inUsage bytesPerRow:inBytesPerRow];
}

- (instancetype) initWithWidth:(NSUInteger)inWidth height:(NSUInteger)inHeight pixelFormat:(MTLPixelFormat)inPfmt storage:(MTLStorageMode)inStorage usage:(MTLTextureUsage)inUsage bytesPerRow:(NSUInteger)inBytesPerRow	{
	self = [super init];
	if (self != nil)	{
		_width = inWidth;
		_height = inHeight;
		_pfmt = inPfmt;
		_storage = inStorage;
		_usage = inUsage;
		_mtlBufferBacking = NO;
		_iosfcBacking = NO;
		_cvpbBacking = NO;
		_bytesPerRow = inBytesPerRow;
	}
	return self;
}

- (BOOL) isVVMTLTextureImageDescriptor	{
	return YES;
}


#pragma mark - NSCopying conformance


- (id) copyWithZone:(NSZone *)z	{
	VVMTLTextureImageDescriptor		*returnMe = [[VVMTLTextureImageDescriptor alloc] init];
	returnMe.width = _width;
	returnMe.height = _height;
	returnMe.pfmt = _pfmt;
	returnMe.storage = _storage;
	returnMe.usage = _usage;
	returnMe.mtlBufferBacking = _mtlBufferBacking;
	returnMe.iosfcBacking = _iosfcBacking;
	returnMe.cvpbBacking = _cvpbBacking;
	returnMe.bytesPerRow = _bytesPerRow;
	return returnMe;
}


#pragma mark - VVMTLRecycleableDescriptor conformance


- (BOOL) matchForRecycling:(id<VVMTLRecycleableDescriptor>)n	{
	if (n == nil || ![(NSObject*)n isVVMTLTextureImageDescriptor])
		return NO;
	VVMTLTextureImageDescriptor		*recast = (VVMTLTextureImageDescriptor *)n;
	if (_width != recast.width
	|| _height != recast.height
	|| _pfmt != recast.pfmt
	|| _storage != recast.storage
	|| _usage != recast.usage
	|| _mtlBufferBacking != recast.mtlBufferBacking
	|| _iosfcBacking != recast.iosfcBacking
	|| _cvpbBacking != recast.cvpbBacking
	|| _bytesPerRow != recast.bytesPerRow)
	{
		return NO;
	}
	
	return YES;
}


@end








@implementation NSObject (VVMTLTextureImageDescriptorNSObjectAdditions)
- (BOOL) isVVMTLTextureImageDescriptor	{
	return NO;
}
@end

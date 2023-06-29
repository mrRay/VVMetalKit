//
//  VVMTLBufferDescriptor.m
//  VVMetalKit
//
//  Created by testadmin on 6/26/23.
//

#import "VVMTLBufferDescriptor.h"




@implementation VVMTLBufferDescriptor

+ (instancetype) createWithLength:(NSUInteger)inLength storage:(MTLStorageMode)inStorage	{
	return [[VVMTLBufferDescriptor alloc] initWithLength:inLength storage:inStorage];
}

- (instancetype) initWithLength:(NSUInteger)inLength storage:(MTLStorageMode)inStorage	{
	self = [super init];
	if (self != nil)	{
		_length = inLength;
		_storage = inStorage;
	}
	return self;
}

- (BOOL) isVVMTLBufferDescriptor	{
	return YES;
}

#pragma mark - NSCopying conformance

- (id) copyWithZone:(NSZone *)z	{
	VVMTLBufferDescriptor		*returnMe = [[VVMTLBufferDescriptor alloc] init];
	returnMe.length = _length;
	returnMe.storage = _storage;
	return returnMe;
}

#pragma mark - VVMTLRecycleableDescriptor conformance

- (BOOL) matchForRecycling:(id<VVMTLRecycleableDescriptor>)n	{
	if (n == nil || ![(NSObject*)n isVVMTLBufferDescriptor])
		return NO;
	VVMTLBufferDescriptor		*recast = (VVMTLBufferDescriptor *)n;
	if (_length != recast.length
	|| _storage != recast.storage)
	{
		return NO;
	}
	
	return YES;
}

@end





@implementation NSObject (VVMTLBufferDescriptorNSObjectAdditions)
- (BOOL) isVVMTLBufferDescriptor	{
	return NO;
}
@end
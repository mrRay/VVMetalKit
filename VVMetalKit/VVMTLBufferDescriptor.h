//
//  VVMTLBufferDescriptor.h
//  VVMetalKit
//
//  Created by testadmin on 6/26/23.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#import <VVMetalKit/VVMTLRecycleableDescriptor.h>

NS_ASSUME_NONNULL_BEGIN




///	Describes a VVMTLBuffer- this class is used as the basis of comparison between VVMTLBuffer instances to determine if they can be used interchangeably (to determine if a buffer in the pool can be recycled when the user requests a new buffer).




@interface VVMTLBufferDescriptor : NSObject <VVMTLRecycleableDescriptor>

+ (instancetype) createWithLength:(NSUInteger)inLength storage:(MTLStorageMode)inStorage;

- (instancetype) initWithLength:(NSUInteger)inLength storage:(MTLStorageMode)inStorage;

@property (assign,readwrite) NSUInteger length;
@property (assign,readwrite) MTLStorageMode storage;

@end




@interface NSObject (VVMTLBufferDescriptorNSObjectAdditions)
@property (readonly) BOOL isVVMTLBufferDescriptor;
@end




NS_ASSUME_NONNULL_END

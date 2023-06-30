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




//	if this class seems smaller "than it should be", remember that it's just a descriptor for a recycleable 
//	resource- all of the properties that describe the image contained by this buffer are irrelevant for the 
//	purpose of the recycleable portion of id<VVMTLBuffer>...




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

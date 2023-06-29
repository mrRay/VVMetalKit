//
//  VVMTLRecycleable.h
//  VVMetalKit
//
//  Created by testadmin on 6/23/23.
//

#ifndef MTLRecycling_h
#define MTLRecycling_h

@protocol VVMTLRecyclingPool;
@protocol VVMTLRecycleableDescriptor;
@protocol VVMTLRecycleable;




typedef void (^VVMTLRecycleableRecycleBlock)(__nonnull id<VVMTLRecycleable>);




@protocol VVMTLRecycleable <NSCopying>

//	receiver will be returned to this pool upon deletion (if the receiver is okay to be recycled!)
@property (readwrite,weak,nullable) id<VVMTLRecyclingPool> pool;

//	NO by default.  if YES, the receiver will not be recycled and its underlying assets will be freed upon its deletion
@property (readwrite) BOOL preferDeletion;
//	used internally- the number of cycles that the receiver has spent in the pool.  when this gets high enough, it will be removed from the pool and deleted.
@property (readwrite) int recycleCount;

//	the descriptor that was likely used to help generate the receiver, and is used to check to see if other recycleables are compatible for re-use
@property (strong,readwrite,nonnull) id<VVMTLRecycleableDescriptor> descriptor;

//	arbitrary supporting object that gets freed when this object gets freed
@property (strong,nullable) id supportingObject;
//	arbitrary supporting context- does not get automatically retained, freed/released, or memory-managed in any way
@property (readwrite,nullable) void * supportingContext;

//	arbitrary block that gets executed when this object gets freed (before the supporting object is released)
@property (nonatomic,copy,nullable) VVMTLRecycleableRecycleBlock deletionBlock;

@end




#endif /* MTLRecycling_h */

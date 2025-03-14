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




///	This type defines the block that will be executed when a recycleable object gets freed.
typedef void (^VVMTLRecycleableRecycleBlock)(__nonnull id<VVMTLRecycleable>);




///	This protocol defines the properties and methods necessary for an object to be recycled by an instance of VVMTLPool




@protocol VVMTLRecycleable <NSCopying>

///	The receiver will be returned to this pool upon deletion (if the receiver is okay to be recycled!).
@property (readwrite,weak,nullable) id<VVMTLRecyclingPool> pool;

///	NO by default.  If YES, the receiver will not be recycled and its underlying assets will be freed upon its deletion.
@property (readwrite) BOOL preferDeletion;
///	Used internally- the number of cycles that the receiver has spent in the pool.  When this gets high enough, it will be removed from the pool and deleted.
@property (readwrite) int recycleCount;

///	The descriptor that was likely used to help generate the receiver, and is used to check to see if other recycleables are compatible for re-use.
@property (copy,readwrite,nonnull) id<VVMTLRecycleableDescriptor> descriptor;

///	Arbitrary supporting object that gets freed when this object gets freed.  Not used by the backend directly- clients of VVMTLPool that want an instance of an object that conforms to the protocol can make use of this.
@property (strong,nullable) id supportingObject;
///	Arbitrary supporting context- does not get automatically retained, freed/released, or memory-managed in any way.  Not used by the backend directly- clients of VVMTLPool that want an instance of an object that conforms to the protocol can make use of this.
@property (readwrite,nullable) void * supportingContext;

///	The deletion block is an arbitrary block that gets executed when this object gets freed (before the supporting object is released).
@property (nonatomic,copy,nullable) VVMTLRecycleableRecycleBlock deletionBlock;

@end




#endif /* MTLRecycling_h */

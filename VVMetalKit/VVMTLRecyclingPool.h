//
//  VVMTLRecyclingPool.h
//  VVMetalKit
//
//  Created by testadmin on 6/23/23.
//

#ifndef MTLRecyclingPool_h
#define MTLRecyclingPool_h

@protocol VVMTLRecycleable;
@protocol VVMTLRecycleableDescriptor;




/**		This protocol defines the methods and properties that implement "pool" functionality- the ability to recycle and fetch recycled objects that match a description
*/




@protocol VVMTLRecyclingPool

//	the passed object is added to the pool without inspection- it is not copied, it is stamped with the time it came back and appended to the end of the array (FIFO)
- (void) recycleObject:(id<VVMTLRecycleable>)n;

//	returns the first pooled object that matches the passed descriptor- the matching object that has waited longest- or nil if no recycleable assets were immediately available
- (id<VVMTLRecycleable>) recycledObjectMatching:(id<VVMTLRecycleableDescriptor>)n;

//	runs through everything in the pool- any object that is due, having sat idle in the pool for at least the pool's idle lifetime, is removed from the pool and deallocated, and the pool's texture cache is flushed
- (void) housekeeping;

@end




#endif /* MTLRecyclingPool_h */

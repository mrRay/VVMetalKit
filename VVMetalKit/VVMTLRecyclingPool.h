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

//	the passed object is added to the pool without inspection- it is not copied, it is just inserted into the array (FIFO)
- (void) recycleObject:(id<VVMTLRecycleable>)n;

//	returns the first pooled object that matches the passed descriptor, or nil if no recycleable assets were immediately available
- (id<VVMTLRecycleable>) recycledObjectMatching:(id<VVMTLRecycleableDescriptor>)n;

//	runs through everything in the pool- if any object's recycleCount is "too high", it's removed from the pool and deallocated
- (void) housekeeping;

@end




#endif /* MTLRecyclingPool_h */

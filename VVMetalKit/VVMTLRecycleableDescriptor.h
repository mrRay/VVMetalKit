//
//  VVMTLRecycleableDescriptor.h
//  VVMetalKit
//
//  Created by testadmin on 6/23/23.
//

#ifndef MTLRecyclingDescriptor_h
#define MTLRecyclingDescriptor_h

//@protocol VVMTLRecycleableDescriptor;




/**		This protocol defines the methods required by a recycling desccriptor.
		- When a pool is asked to create an object (texture/buffer), it first checks to see if it has any existing objects that can be recycled and returned instead.  It does this by comparing the descriptor of the object requested to the descriptor of the available objects.  This protocol defines the methods that the descriptor needs to support to perform this comparison.
*/




@protocol VVMTLRecycleableDescriptor <NSCopying>

- (BOOL) matchForRecycling:(id<VVMTLRecycleableDescriptor>)n;

@end




#endif /* MTLRecyclingDescriptor_h */

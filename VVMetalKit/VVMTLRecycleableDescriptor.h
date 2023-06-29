//
//  VVMTLRecycleableDescriptor.h
//  VVMetalKit
//
//  Created by testadmin on 6/23/23.
//

#ifndef MTLRecyclingDescriptor_h
#define MTLRecyclingDescriptor_h

//@protocol VVMTLRecycleableDescriptor;




@protocol VVMTLRecycleableDescriptor <NSCopying>

- (BOOL) matchForRecycling:(id<VVMTLRecycleableDescriptor>)n;

@end




#endif /* MTLRecyclingDescriptor_h */

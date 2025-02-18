//
//  CIImageAdditions.m
//  CustomFilters
//
//  Created by testadmin on 10/23/24.
//

#import "CIImageAdditions.h"
#import <objc/runtime.h>




static void * CIImageBackingVVMTLTextureImageKey = &CIImageBackingVVMTLTextureImageKey;




@implementation CIImage (CIImageAdditions)

- (id<VVMTLTextureImage>) backingVVMTLTextureImage	{
	return objc_getAssociatedObject(self, CIImageBackingVVMTLTextureImageKey);
}
- (void) setBackingVVMTLTextureImage:(id<VVMTLTextureImage>)n	{
	objc_setAssociatedObject(self, CIImageBackingVVMTLTextureImageKey, n, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

/*
 *  CIImageAdditions.h
 *  VDMX
 *
 *  Created by bagheera on 10/6/11.
 *  Copyright 2011 __MyCompanyName__. All rights reserved.
 *
 */

#import <Cocoa/Cocoa.h>
#import <CoreImage/CoreImage.h>
#import <VVMetalKit/VVMetalKit.h>




@interface CIImage (CIImageAdditions)

@property (strong) id<VVMTLTextureImage> backingVVMTLTextureImage;

@end

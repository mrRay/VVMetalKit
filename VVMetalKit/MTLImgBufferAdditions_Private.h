//
//  MTLImgBufferAdditions_Private.h
//  VVMetalKit
//
//  Created by testAdmin on 4/26/21.
//

#import <Foundation/Foundation.h>
#import "MTLImgBuffer.h"

NS_ASSUME_NONNULL_BEGIN




@interface MTLImgBuffer (MTLImgBufferAdditions_Private)  <NSCopying>

//	called by the buffer pool- returns a new instance of MTLImgBuffer that is basically identical to the passed buffer, and cleans out some properties in the passed buffer so it doesn't clean up after itself on dealloc.  this is how buffer instances are moved back into the pool.
- (instancetype) initByRecycling:(MTLImgBuffer *)n;

@end




NS_ASSUME_NONNULL_END

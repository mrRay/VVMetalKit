//
//  MSLCompModeResource.h
//  MSLCompModes
//
//  Created by testadmin on 5/18/23.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

NS_ASSUME_NONNULL_BEGIN




/*		Data container class, RAII
		- Contains all GPU resources necessary to render a comp mode recipe in a metal rendering environment
		- Only contains GPU resources associated with a single MTLDevice (you'll want to have one of these for each device)
*/




@interface MSLCompModeResource : NSObject

+ (instancetype) createWithDevice:(id<MTLDevice>)inDevice shaderSrc:(NSString *)inSrc;

- (instancetype) initWithDevice:(id<MTLDevice>)inDevice shaderSrc:(NSString *)inSrc;

//	populated on init
@property (readonly,strong) id<MTLDevice> device;

//	these are populated during init
@property (readonly,strong) id<MTLLibrary> lib;
@property (readonly,strong) id<MTLFunction> vtxFunc;
@property (readonly,strong) id<MTLFunction> frgFunc;
@property (readonly,strong) id<MTLRenderPipelineState> pso_8bit;
@property (readonly,strong) id<MTLRenderPipelineState> pso_float;

@end




NS_ASSUME_NONNULL_END

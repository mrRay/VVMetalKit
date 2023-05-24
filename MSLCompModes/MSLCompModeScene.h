//
//  MSLCompModeScene.h
//  MSLCompModes
//
//  Created by testadmin on 5/18/23.
//

#import <Foundation/Foundation.h>

#import <VVMetalKit/VVMetalKit.h>

@class MSLCompModeRecipe;

NS_ASSUME_NONNULL_BEGIN




@interface MSLCompModeScene : MTLRenderScene

@property (strong,readwrite) MSLCompModeRecipe * recipe;

@end




NS_ASSUME_NONNULL_END

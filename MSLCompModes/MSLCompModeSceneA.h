//
//  MSLCompModeSceneA.h
//  MSLCompModes
//
//  Created by testadmin on 5/18/23.
//

#import <Foundation/Foundation.h>

#import <MSLCompModes/MSLCompModeScene.h>

NS_ASSUME_NONNULL_BEGIN




/*		Subclass of VVMTLRenderScene (render/non-compute encoder) that executes MSLCompModeRecipes
		
		The 'A' designation on this class exists because there are other scenes like this that use different 
		technique(s) to render the same recipe.
		
		This scene uses an approach that requires that the host hardware be capable of supporting the color 
		attribute in fragment shaders (ie: '[[ color(n) ]]') for reading the current framebuffer color, which 
		was added back in Metal 2.3 but doesn't work properly due to compiler errors with some (older) GPU hardware/drivers
*/




@interface MSLCompModeSceneA : MSLCompModeScene


@end




NS_ASSUME_NONNULL_END

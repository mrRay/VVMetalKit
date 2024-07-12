//
//  MSLCompModeSceneB.h
//  MSLCompModes
//
//  Created by testadmin on 7/10/24.
//

#import <Foundation/Foundation.h>

#import <MSLCompModes/MSLCompModeScene.h>

NS_ASSUME_NONNULL_BEGIN




/*		Subclass of VVMTLRenderScene (render/non-compute encoder) that executes MSLCompModeRecipes
		
		The 'B' designation on this class exists because there are other scenes like this that use different 
		technique(s) to render the same recipe.
		
		This scene uses an approach that passes pre-calculated homography matrices along with basic descriptions 
		of image crop rects for each layer to the GPU. As each fragment is evaluated, it runs through this array 
		of structs, using the homography matrix to calculate the pixel coords corresponding to this fragment for 
		each layer in turn, and performing composition where those coords are valid (within the src/crop rect).
*/




@interface MSLCompModeSceneB : MSLCompModeScene

@end




NS_ASSUME_NONNULL_END

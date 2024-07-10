//
//  MSLCompModeResourceController.h
//  MSLCompModes
//
//  Created by testadmin on 7/10/24.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

@class MSLCompMode;
@class MSLCompModeResource;

@class MSLCompModeResourceController;

NS_ASSUME_NONNULL_BEGIN




/*		Controller class for creating MSLCompModeResource instances
		- Intended to be used directly (without subclassing)
		- If you don't set it up then this class is basically useless and will do nothing. You need to populate the 'reloadBlock'
		- If you only have one "comp mode shader system", you'll probably only need one instance of this class
		- I need more than one instance, because I have comp mode shaders that are fast and conceptually clean, 
		but they use features that are poorly supported on some (non-apple-silicon) GPUs. Because of this, I 
		also need a different system for older hardware that is a bit slower and not-as-nice conceptually, but 
		functional...so I need a templated system that i can switch between at runtime.
*/




@interface MSLCompModeResourceController : NSObject

+ (instancetype) create;
- (instancetype) init;

//	You MUST POPULATE THIS BLOCK with code that reads the passed array of MSLCompMode instances and returns a string that contains source code for the frag + vert shaders necessary to execute those comp modes
@property (nonatomic,copy,nullable) NSString* (^reloadBlock)(NSArray<MSLCompMode*>*);

//	Once you've populated the 'reloadBlock', call the 'reload' method to have the receiver execute it on all available comp modes. If the available comp modes change, you are responsible for calling this method again.
- (void) reload;

//	once you've reloaded, you can fetch a MSLCompModeResource instance for a given MTLDevice
- (MSLCompModeResource *) resourceForDevice:(id<MTLDevice>)n;

//	the automatically generated shader we compile- useful for diagnostics
@property (strong,readonly,nullable) NSString * shaderSrc;

@end

NS_ASSUME_NONNULL_END

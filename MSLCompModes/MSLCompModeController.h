//
//  MSLCompModeController.h
//  MSLCompModes
//
//  Created by testadmin on 5/17/23.
//

#import <Cocoa/Cocoa.h>

@class MSLCompMode;
@class MSLCompModeControllerResource;

NS_ASSUME_NONNULL_BEGIN




extern NSString * const kMSLCompModeReloadNotificationName;




@interface MSLCompModeController : NSObject

@property (class,readonly) MSLCompModeController * global;

- (void) addCompModeDirectoryURL:(NSURL *)n;
- (void) addCompModeURL:(NSURL *)n;

//	reloads the list of comp modes, re-scanning any directories and checking to make sure that individually-added comp modes still exist
- (void) reload;

//	an array of comp modes, sorted alphabetically by name
@property (readonly) NSArray<MSLCompMode*> * compModes;

//	retrieve the MSLCompModeControllerResource object corresponding to the passed device
- (MSLCompModeControllerResource *) resourceForDevice:(id<MTLDevice>)n;

@end




NS_ASSUME_NONNULL_END

//
//  MSLCompModeController.h
//  MSLCompModes
//
//  Created by testadmin on 5/17/23.
//

#import <Cocoa/Cocoa.h>

@class MSLCompMode;
@class MSLCompModeResourceController;
@class MSLCompModeResource;

NS_ASSUME_NONNULL_BEGIN




//	An NSNotification with this name is posted when the list of comp modes has changed
extern NSString * const kMSLCompModeReloadNotificationName;




/*		Controller class, self-populating global singleton
		- Give it URL(s) to a directory/directories of metal "comp modes" (private format, metal source code with two pre-determined function names), or URLs to specific comp modes.
		- Query it for an array of MSLCompMode instances describing the available comp modes- or ask for specific comp modes by name or compModeIndex.
		- Vends MSLCompModeResource instances
*/




@interface MSLCompModeController : NSObject

@property (class,readonly) MSLCompModeController * global;

- (void) setCompModeDirectoryURLs:(NSArray<NSURL*> *)n;

- (void) addCompModeDirectoryURL:(NSURL *)n;
- (void) addCompModeURL:(NSURL *)n;

//	reloads the list of comp modes, re-scanning any directories and checking to make sure that individually-added comp modes still exist
- (void) reload;

//	an array of comp modes, sorted alphabetically by name
@property (readonly) NSArray<MSLCompMode*> * compModes;

- (MSLCompMode *) compModeWithName:(NSString *)n;
- (MSLCompMode *) compModeWithIndex:(uint16_t)n;

//	retrieve the MSLCompModeResource object corresponding to the passed device
//- (MSLCompModeResource *) resourceForDevice:(id<MTLDevice>)n;

//	this controller will vend MSLCompModeResource instances for use with MSLCompModeSceneA
@property (strong,readonly) MSLCompModeResourceController * rsrcCtrlrA;
//	this controller will vend MSLCompModeResource instances for use with MSLCompModeSceneB
@property (strong,readonly) MSLCompModeResourceController * rsrcCtrlrB;

@end




NS_ASSUME_NONNULL_END

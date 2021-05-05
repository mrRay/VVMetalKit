#import <Cocoa/Cocoa.h>



///	Different sizing modes
/**
\ingroup VVBufferPool
*/
typedef NS_ENUM(NSInteger,VVSizingMode)	{
	VVSizingModeFit = 0,	//!<	the content is made as large as possible, proportionally, without cutting itself off or going outside the bounds of the desired area
	VVSizingModeFill = 1,	//!<	the content is made as large as possible, proportionally, to fill the desired area- some of the content may get cut off
	VVSizingModeStretch = 2,	//!<	the content is scaled to fit perfectly within the desired area- some stretching or squashing may occur, this isn't necessarily proportional
	VVSizingModeCopy = 3	//!<	the content is copied directly to the desired area- it is not made any larger or smaller
};



///	Simplifies the act of generating transforms and other geometry-related data around the relatively common act of resizing one rect to fit inside another.
/**
\ingroup VVBufferPool
*/
@interface COM_VIDVOX_VVMETALKIT_VVSizingTool : NSObject {

}

+ (CGRect) rectThatFitsRect:(CGRect)a inRect:(CGRect)b sizingMode:(VVSizingMode)m;

@end


//	make VVSizingTool an alias for COM_VIDVOX_VVMETALKIT_VVSizingTool
@compatibility_alias VVSizingTool COM_VIDVOX_VVMETALKIT_VVSizingTool;


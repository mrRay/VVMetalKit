#import "VVSizingTool.h"




@implementation VVSizingTool


+ (CGRect) rectThatFitsRect:(CGRect)a inRect:(CGRect)b sizingMode:(VVSizingMode)m	{
	CGRect		returnMe = CGRectMake(0,0,0,0);
	double		bAspect = b.size.width/b.size.height;
	double		aAspect = a.size.width/a.size.height;
	switch (m)	{
		case VVSizingModeFit:
			//	if the rect i'm trying to fit stuff *into* is wider than the rect i'm resizing
			if (bAspect > aAspect)	{
				returnMe.size.height = b.size.height;
				returnMe.size.width = returnMe.size.height * aAspect;
			}
			//	else if the rect i'm resizing is wider than the rect it's going into
			else if (bAspect < aAspect)	{
				returnMe.size.width = b.size.width;
				returnMe.size.height = returnMe.size.width / aAspect;
			}
			else	{
				returnMe.size.width = b.size.width;
				returnMe.size.height = b.size.height;
			}
			returnMe.origin.x = (b.size.width-returnMe.size.width)/2.0+b.origin.x;
			returnMe.origin.y = (b.size.height-returnMe.size.height)/2.0+b.origin.y;
			break;
		case VVSizingModeFill:
			//	if the rect i'm trying to fit stuff *into* is wider than the rect i'm resizing
			if (bAspect > aAspect)	{
				returnMe.size.width = b.size.width;
				returnMe.size.height = returnMe.size.width / aAspect;
			}
			//	else if the rect i'm resizing is wider than the rect it's going into
			else if (bAspect < aAspect)	{
				returnMe.size.height = b.size.height;
				returnMe.size.width = returnMe.size.height * aAspect;
			}
			else	{
				returnMe.size.width = b.size.width;
				returnMe.size.height = b.size.height;
			}
			returnMe.origin.x = (b.size.width-returnMe.size.width)/2.0+b.origin.x;
			returnMe.origin.y = (b.size.height-returnMe.size.height)/2.0+b.origin.y;
			break;
		case VVSizingModeStretch:
			returnMe = CGRectMake(b.origin.x,b.origin.y,b.size.width,b.size.height);
			break;
		case VVSizingModeCopy:
			returnMe.size = CGSizeMake((double)(int)a.size.width,(double)(int)a.size.height);
			returnMe.origin.x = (double)(int)((b.size.width-returnMe.size.width)/2.0+b.origin.x);
			returnMe.origin.y = (double)(int)((b.size.height-returnMe.size.height)/2.0+b.origin.y);
			break;
	}
	
	return returnMe;
}


@end

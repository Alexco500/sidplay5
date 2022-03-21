#import "SPSourceListCell.h"
#import "SPSourceListDataSource.h"


static const float sLeftMargin = 3.0f;
static const float sImageTextSpacing = 3.0f;
static const float sVerticalMargin = 4.0f;

static const int sIconWidth = 16.0f;
static const int sIconHeight = 16.0f;

@implementation SPSourceListCell



// ----------------------------------------------------------------------------
- (id) init
// ----------------------------------------------------------------------------
{
	self = [super init];
	if (self != nil)
	{
		image = nil;
		progressIndicator = nil;
	}
	return self;
}


// ----------------------------------------------------------------------------
- (id) copyWithZone:(NSZone*)zone
// ----------------------------------------------------------------------------
{
    SPSourceListCell *cell = (SPSourceListCell *)[super copyWithZone:zone];
    cell->image = image;
    return cell;
}


// ----------------------------------------------------------------------------
- (void) setImage:(NSImage *)anImage
// ----------------------------------------------------------------------------
{
    if (anImage != image)
        image = anImage;
}


// ----------------------------------------------------------------------------
- (NSImage*) image
// ----------------------------------------------------------------------------
{
    return image;
}


// ----------------------------------------------------------------------------
- (NSRect) imageFrameForCellFrame:(NSRect)cellFrame
// ----------------------------------------------------------------------------
{
    if (image != nil)
	{
        NSRect imageFrame;
        imageFrame.size.width = sIconWidth;
        imageFrame.size.height = sIconHeight;
        imageFrame.origin = cellFrame.origin;
        imageFrame.origin.x += sLeftMargin;
        imageFrame.origin.y += ceil((cellFrame.size.height - imageFrame.size.height) / 2);
        return imageFrame;
    }
    else
        return NSZeroRect;
}


// ----------------------------------------------------------------------------
- (void) editWithFrame:(NSRect)rect inView:(NSView*)controlView editor:(NSText*)textObj delegate:(id)anObject event:(NSEvent*)event
// ----------------------------------------------------------------------------
{
	NSRect centeredFrame = [self drawingRectForBounds:rect];
    NSRect textFrame;
	NSRect imageFrame;
    NSDivideRect(centeredFrame, &imageFrame, &textFrame, sLeftMargin + sImageTextSpacing + [image size].width, NSMinXEdge);
	textFrame.size.width -= 1.0f;
	//NSAttributedString* string = [self attributedStringValue];
	//textFrame.size.width = [string size].width + sLeftMargin;
    [super editWithFrame:textFrame inView:controlView editor:textObj delegate:anObject event:event];
}


// ----------------------------------------------------------------------------
- (void)selectWithFrame:(NSRect)rect inView:(NSView*)controlView editor:(NSText*)textObj delegate:(id)anObject start:(NSInteger)selStart length:(NSInteger)selLength
// ----------------------------------------------------------------------------
{
	NSRect centeredFrame = [self drawingRectForBounds:rect];
    NSRect textFrame;
	NSRect imageFrame;
    NSDivideRect(centeredFrame, &imageFrame, &textFrame, sLeftMargin + sImageTextSpacing + [image size].width, NSMinXEdge);
	textFrame.size.width -= 1.0f;
	//NSAttributedString* string = [self attributedStringValue];
	//textFrame.size.width = [string size].width + sLeftMargin;
    [super selectWithFrame:textFrame inView:controlView editor:textObj delegate:anObject start:selStart length:selLength];
}


// ----------------------------------------------------------------------------
- (NSRect) drawingRectForBounds:(NSRect)theRect
// ----------------------------------------------------------------------------
{
	// Get the parent's idea of where we should draw
	NSRect newRect = [super drawingRectForBounds:theRect];

	// Get our ideal size for current text
	NSSize textSize = [self cellSizeForBounds:theRect];

	// Center that in the proposed rect
	float heightDelta = newRect.size.height - textSize.height;	
	if (heightDelta > 0.0f)
	{
		newRect.size.height -= heightDelta;
		newRect.origin.y += heightDelta / 2.0f;
	}
	
	return newRect;
}


// ----------------------------------------------------------------------------
- (void) drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
// ----------------------------------------------------------------------------
{
    if (image != nil) 
	{
        NSRect imageFrame;

		float iconHeight = sIconWidth;
		float iconWidth = sIconHeight;
		
        NSDivideRect(cellFrame, &imageFrame, &cellFrame, sLeftMargin + iconWidth + sImageTextSpacing, NSMinXEdge);
        if ([self drawsBackground]) 
		{
            [[self backgroundColor] set];
            NSRectFill(imageFrame);
        }
		
        imageFrame.origin.x += sLeftMargin;
        imageFrame.origin.y += sVerticalMargin;
        imageFrame.size.width = iconWidth;
        imageFrame.size.height = iconHeight;

		NSRect imageRect = NSMakeRect(0.0f, 0.0f, [image size].width, [image size].height);
		
		[image setFlipped:[controlView isFlipped]];
		[image drawInRect:imageFrame fromRect:imageRect operation:NSCompositeSourceOver fraction:1.0f];
	}

	if (progressIndicator != nil)
	{
        NSRect progressFrame;
        NSDivideRect(cellFrame, &progressFrame, &cellFrame, 16.0f, NSMaxXEdge);
		progressFrame = NSInsetRect(progressFrame, 0.0f, (cellFrame.size.height - 16.0f) / 2.0f);

		if([progressIndicator superview] == nil)
		{
			[controlView addSubview:progressIndicator];
		}
		[progressIndicator setFrame:progressFrame];
	}

    [super drawInteriorWithFrame:cellFrame inView:controlView];
}


// ----------------------------------------------------------------------------
- (NSSize) cellSize
// ----------------------------------------------------------------------------
{
    NSSize cellSize = [super cellSize];
	float imageSize = cellSize.height - 2.0f * sVerticalMargin;
    cellSize.width += (image ? imageSize : 0) + sLeftMargin + sImageTextSpacing;
	
    return cellSize;
}


// ----------------------------------------------------------------------------
- (BOOL) isEditable
// ----------------------------------------------------------------------------
{
	return YES;
}


// ----------------------------------------------------------------------------
- (void) setProgressIndicator:(NSProgressIndicator*)indicator
// ----------------------------------------------------------------------------
{
	progressIndicator = indicator;
}


@end

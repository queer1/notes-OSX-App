//
//  OCNotesViewController.m
//  CloudNotes
//
//  Created by Peter Hedlund on 2/4/14.
//  Copyright (c) 2014 Peter Hedlund. All rights reserved.
//

#import "OCNotesViewController.h"
#import "OCNotesHelper.h"
#import "Note.h"
#import "OCEditorSettings.h"
#import "NSSplitView+SaveLayout.h"

@interface OCNotesViewController () {
    NSTimer *editingTimer;
    NSRange selection;
    CGPoint clipOrigin;
    NSResponder *currentResponder;
}

@end

@implementation OCNotesViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self.splitView loadLayoutWithName:@"SplitViewLayout"];

    self.contentTextView.textContainerInset = NSMakeSize(25, 25);
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(noteUpdated:)
                                                 name:NSManagedObjectContextDidSaveNotification
                                               object:nil];
    
    [self updateFont];
}

- (IBAction)doSync:(id)sender {
    [[OCNotesHelper sharedHelper] sync];
}

- (IBAction)doAdd:(id)sender {
    [[OCNotesHelper sharedHelper] addNote:@""];
}

- (IBAction)doDelete:(id)sender {
    Note *noteToDelete = nil;
    if ([[self.notesArrayController selectedObjects] count] > 0) {
        noteToDelete = (Note*)[[self.notesArrayController selectedObjects] objectAtIndex:0];
        [[OCNotesHelper sharedHelper] deleteNote:noteToDelete];
    }
}

- (IBAction)doExport:(id)sender {
    if ([[self.notesArrayController selectedObjects] count] > 0) {
        __block Note *noteToExport = (Note*)[[self.notesArrayController selectedObjects] objectAtIndex:0];
        
        NSSavePanel* savePanel = [NSSavePanel savePanel];
        savePanel.title = @"Export note as...";
        savePanel.showsResizeIndicator = YES;
        savePanel.showsHiddenFiles = NO;
        savePanel.canCreateDirectories = YES;
        savePanel.allowedFileTypes = @[@"txt"];
        savePanel.nameFieldStringValue = noteToExport.title;
        
        [savePanel beginSheetModalForWindow:self.view.window
                          completionHandler:^(NSInteger result) {
                              if (result == NSFileHandlingPanelOKButton) {
                                  NSString *contentToExport = noteToExport.content;
                                  [contentToExport writeToURL:savePanel.URL atomically:YES encoding:NSUTF8StringEncoding error:nil];
                              }
                          }];
    }
}

- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview {
    return NO;
}

#pragma mark - Split View Delegate

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedCoordinate ofSubviewAt:(int)index
{
	return proposedCoordinate + 120;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedCoordinate ofSubviewAt:(int)index
{
	return proposedCoordinate - 120;
}

- (void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{
	NSRect newFrame = [sender frame]; // get the new size of the whole splitView
	NSView *left = [[sender subviews] objectAtIndex:0];
	NSRect leftFrame = [left frame];
	NSView *right = [[sender subviews] objectAtIndex:1];
	NSRect rightFrame = [right frame];
    
	CGFloat dividerThickness = [sender dividerThickness];
    
	leftFrame.size.height = newFrame.size.height;
    
	rightFrame.size.width = newFrame.size.width - leftFrame.size.width - dividerThickness;
	rightFrame.size.height = newFrame.size.height;
	rightFrame.origin.x = leftFrame.size.width + dividerThickness;
    
	[left setFrame:leftFrame];
	[right setFrame:rightFrame];
}

#pragma mark - Table View Delegate

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
    [self.tableCellView bind:NSSelectedObjectBinding toObject:self.notesArrayController withKeyPath:@"selection" options:nil];
    Note *note = [[self.notesArrayController selectedObjects] firstObject];
    NSLog(@"Selected Row: %ld Title %@", (long)self.tableView.selectedRow, note.title);

    [[OCNotesHelper sharedHelper] getNote:note];
    self.contentTextView.string = note.content;
    selection = NSMakeRange(0, 0);
    [self updateFont];
}

- (NSArray *)idSortDescriptor {
    return @[[NSSortDescriptor sortDescriptorWithKey:@"myId" ascending:NO]];
}

#pragma mark - Text View Delegate

- (void)textDidChange:(NSNotification *)obj {
    if (editingTimer) {
        [editingTimer invalidate];
        editingTimer = nil;
    }
    editingTimer = [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(updateText:) userInfo:nil repeats:NO];
}

- (void)updateText:(NSTimer*)timer {
    NSLog(@"Ready to update text");
    Note *noteToUpdate = nil;
    if ([[self.notesArrayController selectedObjects] count] > 0) {
        selection = self.contentTextView.selectedRange;
        clipOrigin = self.contentTextView.enclosingScrollView.contentView.bounds.origin;
        currentResponder = self.contentTextView.window.firstResponder;
        noteToUpdate = (Note*)[[self.notesArrayController selectedObjects] objectAtIndex:0];
        [[OCNotesHelper sharedHelper] updateNote:noteToUpdate];
    }
}

- (void)noteUpdated:(NSNotification *)notification {
    [self updateFont];
    self.contentTextView.selectedRange = selection;
    [self.contentTextView.enclosingScrollView.contentView scrollToPoint: clipOrigin];
    [self.contentTextView.enclosingScrollView reflectScrolledClipView:self.contentTextView.enclosingScrollView.contentView];
    if (currentResponder) {
        [self.contentTextView.window makeFirstResponder:currentResponder];
    }
}

- (void)updateFont {
    NSURL *saveUrl = [[OCNotesHelper sharedHelper] applicationFilesDirectory];
    saveUrl = [saveUrl URLByAppendingPathComponent:@"settings" isDirectory:NO];
    saveUrl = [saveUrl URLByAppendingPathExtension:@"plist"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:[saveUrl path]]) {
        OCEditorSettings *settings = [NSKeyedUnarchiver unarchiveObjectWithFile:[saveUrl path]];
        self.contentTextView.textStorage.font = settings.font;
        self.contentTextView.font = settings.font;
    }
}

@end

//
//  RLMPopupViewController.m
//  RealmBrowser
//
//  Created by Gustaf Kugelberg on 29/09/14.
//  Copyright (c) 2014 Realm inc. All rights reserved.
//

#import "RLMPopupViewController.h"
#import "RLMDescriptions.h"

#import "RLMPopupWindow.h"

#import "RLMTableColumn.h"
#import "RLMArrayNode.h"

#import "RLMBadgeTableCellView.h"
#import "RLMBasicTableCellView.h"
#import "RLMBoolTableCellView.h"
#import "RLMNumberTableCellView.h"
#import "RLMImageTableCellView.h"

#import "RLMRealmBrowserWindowController.h"
#import "RLMInstanceTableViewController.h"

#import "RLMTableHeaderCell.h"

@interface RLMPopupViewController () <NSTableViewDelegate, NSTableViewDataSource>

@property (nonatomic) RLMDescriptions *realmDescriptions;
@property (nonatomic) IBOutlet NSTableView *tableView;

@property (nonatomic) RLMPopupWindow *popupWindow;
@property (nonatomic) NSTrackingArea *trackingArea;

@property (weak, nonatomic) RLMInstanceTableViewController *owningTableViewController;

@end


@implementation RLMPopupViewController

-(id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.realmDescriptions = [[RLMDescriptions alloc] init];
    }
    
    return self;
}

-(void)setupFromWindow:(NSWindow *)parentWindow
{
    self.popupWindow = [[RLMPopupWindow alloc] initWithView:self.view];
    self.popupWindow.alphaValue = 0.0;
    [parentWindow addChildWindow:self.popupWindow ordered:NSWindowAbove];
    
    RLMRealmBrowserWindowController *wc = parentWindow.windowController;
    self.owningTableViewController = wc.tableViewController;
}

- (void)createTrackingArea
{
    int opts = (NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingInVisibleRect);
    self.trackingArea = [[NSTrackingArea alloc] initWithRect:[self.popupWindow.contentView bounds] options:opts owner:self userInfo:nil];
    
    [self.popupWindow.contentView addTrackingArea:self.trackingArea];
}

#pragma mark - Public Methods

- (void)updateTableView
{
    [self.tableView reloadData];
}

- (void)updateTableColumnsWithArrayNode:(RLMArrayNode *)arrayNode
{
    while (self.tableView.numberOfColumns > 0) {
        [self.tableView removeTableColumn:[self.tableView.tableColumns lastObject]];
    }
    [self.tableView reloadData];
 
    
    NSRect frame = self.tableView.headerView.frame;
    frame.size.height = 36;
    self.tableView.headerView.frame = frame;
    
    [self.tableView beginUpdates];

    // If array, add extra first column with numbers
    RLMTableColumn *tableColumn = [[RLMTableColumn alloc] initWithIdentifier:@"#"];
    tableColumn.propertyType = RLMPropertyTypeInt;
    
    RLMTableHeaderCell *headerCell = [[RLMTableHeaderCell alloc] init];
    headerCell.wraps = YES;
    headerCell.firstLine = @"";
    headerCell.secondLine = @"#";
    tableColumn.headerCell = headerCell;
    
    tableColumn.width = [tableColumn sizeThatFitsWithLimit:YES];
    
    [self.tableView addTableColumn:tableColumn];

    // ... and add new columns matching the structure of the new realm table.
    NSArray *propertyColumns = arrayNode.propertyColumns;
    
    for (NSUInteger index = 0; index < propertyColumns.count; index++) {
        RLMClassProperty *propertyColumn = propertyColumns[index];

        RLMTableColumn *tableColumn = [[RLMTableColumn alloc] initWithIdentifier:propertyColumn.name];
        tableColumn.propertyType = propertyColumn.type;
        
        RLMTableHeaderCell *headerCell = [[RLMTableHeaderCell alloc] init];
        headerCell.wraps = YES;
        headerCell.firstLine = propertyColumn.name;
        headerCell.secondLine = [RLMDescriptions nameOfProperty:propertyColumn.property];
        tableColumn.headerCell = headerCell;
        
        tableColumn.width = [tableColumn sizeThatFitsWithLimit:YES];

        [self.tableView addTableColumn:tableColumn];
    }
    
    [self.tableView endUpdates];
    [self.tableView deselectAll:self];
}

-(void)setArrayNode:(RLMArrayNode *)arrayNode
{
    if (![arrayNode.schema isEqual:_arrayNode.schema]) {
        [self updateTableColumnsWithArrayNode:arrayNode];
    }
    
    _arrayNode = arrayNode;
}

- (void)setDisplayPoint:(NSPoint)displayPoint
{
    if (displayPoint.x != _displayPoint.x || displayPoint.y != _displayPoint.y) {
        _displayPoint = displayPoint;
        [self.popupWindow updateGeometryAtPoint:displayPoint];
    }
}

- (void)showWindow
{
    self.popupWindow.animator.alphaValue = 1.0;
    [self.popupWindow makeKeyAndOrderFront:self];
    self.showingWindow = YES;
    [self createTrackingArea];
}

- (void)hideWindow
{
    self.popupWindow.animator.alphaValue = 0.0;
    self.showingWindow = NO;
    for (NSTrackingArea *trackingArea in [self.popupWindow.contentView trackingAreas]) {
        [self.popupWindow.contentView removeTrackingArea:trackingArea];
    }
}

#pragma mark - NSTableView Delegate

-(CGFloat)tableView:(NSTableView *)tableView sizeToFitWidthOfColumn:(NSInteger)column
{
    RLMTableColumn *tableColumn = self.tableView.tableColumns[column];
    return [tableColumn sizeThatFitsWithLimit:NO];
}

#pragma mark - NSTableView Data Source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return self.arrayNode.instanceCount;
}

-(NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{    
    NSUInteger column = [tableView.tableColumns indexOfObject:tableColumn];
    NSInteger propertyIndex = column - 1;
    
    // Array gutter
    if (propertyIndex == -1) {
        RLMBasicTableCellView *basicCellView = [tableView makeViewWithIdentifier:@"IndexCell" owner:self];
        basicCellView.textField.stringValue = [@(rowIndex) stringValue];
        basicCellView.textField.editable = NO;
        
        return basicCellView;
    }
    
    RLMClassProperty *classProperty = self.arrayNode.propertyColumns[propertyIndex];
    RLMObject *selectedInstance = [self.arrayNode instanceAtIndex:rowIndex];
    id propertyValue = selectedInstance[classProperty.name];
    RLMPropertyType type = classProperty.type;
    
    switch (type) {
        case RLMPropertyTypeArray: {
            RLMBadgeTableCellView *badgeCellView = [tableView makeViewWithIdentifier:@"BadgeCell" owner:self];
            badgeCellView.textField.stringValue = [self.realmDescriptions printablePropertyValue:propertyValue ofType:type];
            badgeCellView.textField.editable = NO;
            badgeCellView.badge.hidden = NO;
            badgeCellView.badge.title = [NSString stringWithFormat:@"%lu", [(RLMArray *)propertyValue count]];
            
            return badgeCellView;
        }
        case RLMPropertyTypeBool: {
            RLMBoolTableCellView *boolCellView = [tableView makeViewWithIdentifier:@"BoolCell" owner:self];
            boolCellView.checkBox.state = [(NSNumber *)propertyValue boolValue] ? NSOnState : NSOffState;
            [boolCellView.checkBox setEnabled:NO];
            
            return boolCellView;
        }
        case RLMPropertyTypeInt:
        case RLMPropertyTypeFloat:
        case RLMPropertyTypeDouble: {
            RLMNumberTableCellView *numberCellView = [tableView makeViewWithIdentifier:@"NumberCell" owner:self];
            numberCellView.textField.stringValue = [self.realmDescriptions printablePropertyValue:propertyValue ofType:type];
            numberCellView.textField.editable = NO;
            
            return numberCellView;
        }
        case RLMPropertyTypeObject: {
            RLMLinkTableCellView *linkCellView = [tableView makeViewWithIdentifier:@"LinkCell" owner:self];
            linkCellView.textField.stringValue = [self.realmDescriptions printablePropertyValue:propertyValue ofType:type];
            linkCellView.textField.editable = NO;
            
            return linkCellView;
        }
        case RLMPropertyTypeData:
        case RLMPropertyTypeAny:
        case RLMPropertyTypeDate:
        case RLMPropertyTypeString: {
            RLMBasicTableCellView *basicCellView = [tableView makeViewWithIdentifier:@"BasicCell" owner:self];
            basicCellView.textField.stringValue = [self.realmDescriptions printablePropertyValue:propertyValue ofType:type];
            basicCellView.textField.editable = NO;
            
            return basicCellView;
        }
        default:
            return nil;
    }
}

#pragma mark - Mouse Handling
-(void)mouseExited:(NSEvent *)theEvent
{
    [self.owningTableViewController mouseDidLeaveCellOrView];
}

@end

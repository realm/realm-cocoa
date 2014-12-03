////////////////////////////////////////////////////////////////////////////
//
// Copyright 2014 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

#import "RLMInstanceTableViewController.h"
#import <Foundation/Foundation.h>

#import "RLMPopupViewController.h"
#import "RLMRealmBrowserWindowController.h"
#import "RLMArrayNavigationState.h"
#import "RLMQueryNavigationState.h"
#import "RLMArrayNode.h"
#import "RLMRealmNode.h"

#import "RLMBadgeTableCellView.h"
#import "RLMBasicTableCellView.h"
#import "RLMBoolTableCellView.h"
#import "RLMNumberTableCellView.h"
#import "RLMImageTableCellView.h"

#import "RLMTableColumn.h"

#import "NSColor+ByteSizeFactory.h"

#import "objc/objc-class.h"

#import "RLMDescriptions.h"

NSString * const kRLMObjectType = @"RLMObjectType";

typedef NS_ENUM(int32_t, RLMUpdateType) {
    RLMUpdateTypeRealm,
    RLMUpdateTypeTableView
};

@interface RLMRealm ()

- (RLMObject *)createObject:(NSString *)className withObject:(id)object;

@end


@interface RLMInstanceTableViewController ()

@property (nonatomic) RLMPopupViewController *popupController;

@end


@implementation RLMInstanceTableViewController {
    BOOL awake;
    BOOL linkCursorDisplaying;
    NSDateFormatter *dateFormatter;
    NSNumberFormatter *numberFormatter;
    NSMutableDictionary *autofittedColumns;
    RLMDescriptions *realmDescriptions;
}

#pragma mark - NSObject Overrides

- (void)awakeFromNib
{
    [super awakeFromNib];

    if (awake) {
        return;
    }
    
    [self.tableView setTarget:self];
    [self.tableView setAction:@selector(userClicked:)];
    [self.tableView setDoubleAction:@selector(userDoubleClicked:)];

    dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateStyle = NSDateFormatterMediumStyle;
    dateFormatter.timeStyle = NSDateFormatterShortStyle;
    
    numberFormatter = [[NSNumberFormatter alloc] init];
    numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
    
    linkCursorDisplaying = NO;
    
    autofittedColumns = [NSMutableDictionary dictionary];
    
    realmDescriptions = [[RLMDescriptions alloc] init];
    
    [self.tableView registerForDraggedTypes:@[kRLMObjectType]];
    [self.tableView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];

    self.popupController = [[RLMPopupViewController alloc] initWithNibName:@"RLMPopupViewController" bundle:nil];
    [self.popupController setupFromWindow:self.parentWindowController.window];
    
    awake = YES;
}

#pragma mark - Public methods - Accessors

- (RLMTableView *)realmTableView
{
    return (RLMTableView *)self.tableView;
}

#pragma mark - RLMViewController Overrides

- (void)performUpdateUsingState:(RLMNavigationState *)newState oldState:(RLMNavigationState *)oldState
{
    [super performUpdateUsingState:newState oldState:oldState];
    
    [self.tableView setAutosaveTableColumns:NO];
    
    RLMRealm *realm = self.parentWindowController.modelDocument.presentedRealm.realm;
    
    if ([newState isMemberOfClass:[RLMNavigationState class]]) {
        self.displayedType = newState.selectedType;
        [self.realmTableView setupColumnsWithType:newState.selectedType];
        [self setSelectionIndex:newState.selectedInstanceIndex];
    }
    else if ([newState isMemberOfClass:[RLMArrayNavigationState class]]) {
        RLMArrayNavigationState *arrayState = (RLMArrayNavigationState *)newState;
        
        RLMClassNode *referringType = (RLMClassNode *)arrayState.selectedType;
        RLMObject *referingInstance = [referringType instanceAtIndex:arrayState.selectedInstanceIndex];
        RLMArrayNode *arrayNode = [[RLMArrayNode alloc] initWithReferringProperty:arrayState.property
                                                                         onObject:referingInstance
                                                                            realm:realm];
        self.displayedType = arrayNode;
        [self.realmTableView setupColumnsWithType:arrayNode];
        [self setSelectionIndex:arrayState.arrayIndex];
    }
    else if ([newState isMemberOfClass:[RLMQueryNavigationState class]]) {
        RLMQueryNavigationState *arrayState = (RLMQueryNavigationState *)newState;
        
        RLMArrayNode *arrayNode = [[RLMArrayNode alloc] initWithQuery:arrayState.searchText
                                                               result:arrayState.results
                                                            andParent:arrayState.selectedType];
        self.displayedType = arrayNode;
        [self.realmTableView setupColumnsWithType:arrayNode];
        [self setSelectionIndex:0];
    }
    
    self.tableView.autosaveName = [NSString stringWithFormat:@"%lu:%@", realm.hash, self.displayedType.name];
    [self.tableView setAutosaveTableColumns:YES];
    
    if (![autofittedColumns[self.tableView.autosaveName] isEqual:@YES]) {
        [self.realmTableView makeColumnsFitContents];
        autofittedColumns[self.tableView.autosaveName] = @YES;
    }
}

#pragma mark - RLMTextField Delegate

-(void)textFieldCancelledEditing:(RLMTextField *)textField
{
    [self.tableView reloadData];
}

#pragma mark - NSTableView Data Source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    if (tableView != self.tableView) {
        return 0;
    }
    
    return self.displayedType.instanceCount;
}

- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
    if (self.realmIsLocked || !self.displaysArray) {
        return NO;
    }
    
    NSData *indexSetData = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
    [pboard declareTypes:@[kRLMObjectType] owner:self];
    [pboard setData:indexSetData forType:kRLMObjectType];
    
    return YES;
}

- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation
{
    if (operation == NSTableViewDropAbove) {
        return NSDragOperationMove;
    }
    
    return NSDragOperationNone;
}

-(void)tableView:(NSTableView *)tableView draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)screenPoint forRowIndexes:(NSIndexSet *)rowIndexes {
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)destination dropOperation:(NSTableViewDropOperation)operation
{
    if (self.realmIsLocked || !self.displaysArray) {
        return NO;
    }
    
    // Check that the dragged item is of correct type
    NSArray *supportedTypes = @[kRLMObjectType];
    NSPasteboard *draggingPasteboard = [info draggingPasteboard];
    NSString *availableType = [draggingPasteboard availableTypeFromArray:supportedTypes];
    
    if ([availableType compare:kRLMObjectType] == NSOrderedSame) {
        NSData *rowIndexData = [draggingPasteboard dataForType:kRLMObjectType];
        NSIndexSet *rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:rowIndexData];
        
        // Performs the move in the realm
        [self moveRowsInRealmFrom:rowIndexes to:destination];

        // Performs the move visually in all relevant windows
        [self.parentWindowController moveRowsInTableViewForArrayNode:(RLMArrayNode *)self.displayedType from:rowIndexes to:destination];
        
        return YES;
    }
    
    return NO;
}

#pragma mark - RLMTableView Data Source

-(NSString *)headerToolTipForColumn:(RLMClassProperty *)propertyColumn
{
    numberFormatter.maximumFractionDigits = 3;

    // For certain types we want to add some statistics
    RLMPropertyType type = propertyColumn.property.type;
    NSString *propertyName = propertyColumn.property.name;
    
    if (![self.displayedType isKindOfClass:[RLMClassNode class]]) {
        return nil;
    }
    
    RLMResults *tvArray = ((RLMClassNode *)self.displayedType).allObjects;
    switch (type) {
        case RLMPropertyTypeInt:
        case RLMPropertyTypeFloat:
        case RLMPropertyTypeDouble: {
            numberFormatter.minimumFractionDigits = type == RLMPropertyTypeInt ? 0 : 3;
            NSString *min = [numberFormatter stringFromNumber:[tvArray minOfProperty:propertyName]];
            NSString *avg = [numberFormatter stringFromNumber:[tvArray averageOfProperty:propertyName]];
            NSString *max = [numberFormatter stringFromNumber:[tvArray maxOfProperty:propertyName]];
            NSString *sum = [numberFormatter stringFromNumber:[tvArray sumOfProperty:propertyName]];
            
            return [NSString stringWithFormat:@"Minimum: %@\nAverage: %@\nMaximum: %@\nSum: %@", min, avg, max, sum];
        }
        case RLMPropertyTypeDate: {
            NSString *min = [dateFormatter stringFromDate:[tvArray minOfProperty:propertyName]];
            NSString *max = [dateFormatter stringFromDate:[tvArray maxOfProperty:propertyName]];
            
            return [NSString stringWithFormat:@"Earliest: %@\nLatest: %@", min, max];
        }
        default:
            return nil;
    }
}

#pragma mark - NSTableView Delegate

-(CGFloat)tableView:(NSTableView *)tableView sizeToFitWidthOfColumn:(NSInteger)column
{
    RLMTableColumn *tableColumn = self.realmTableView.tableColumns[column];
    
    return [tableColumn sizeThatFitsWithLimit:NO];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    if (self.tableView == notification.object) {
        NSInteger selectedIndex = self.tableView.selectedRow;
        [self.parentWindowController.currentState updateSelectionToIndex:selectedIndex];
    }
}

-(NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
    if (tableView != self.tableView) {
        return nil;
    }
    
    NSUInteger column = [tableView.tableColumns indexOfObject:tableColumn];
    NSInteger propertyIndex = [self propertyIndexForColumn:column];
    
    // Array gutter
    if (propertyIndex == -1) {
        RLMBasicTableCellView *basicCellView = [tableView makeViewWithIdentifier:@"IndexCell" owner:self];
        basicCellView.textField.stringValue = [@(rowIndex) stringValue];
        basicCellView.textField.editable = NO;
        
        return basicCellView;
    }
    
    RLMClassProperty *classProperty = self.displayedType.propertyColumns[propertyIndex];
    RLMObject *selectedInstance = [self.displayedType instanceAtIndex:rowIndex];
    id propertyValue = selectedInstance[classProperty.name];
    RLMPropertyType type = classProperty.type;
    
    NSTableCellView *cellView;
    
    switch (type) {
        case RLMPropertyTypeArray: {
            RLMBadgeTableCellView *badgeCellView = [tableView makeViewWithIdentifier:@"BadgeCell" owner:self];
            NSString *string = [realmDescriptions printablePropertyValue:propertyValue ofType:type];
            NSDictionary *attr = @{NSUnderlineStyleAttributeName : @(NSUnderlineStyleSingle)};
            badgeCellView.textField.attributedStringValue = [[NSAttributedString alloc] initWithString:string attributes:attr];
            badgeCellView.textField.editable = NO;

            badgeCellView.badge.hidden = NO;
            badgeCellView.badge.title = [NSString stringWithFormat:@"%lu", [(RLMArray *)propertyValue count]];
            [badgeCellView.badge.cell setHighlightsBy:0];
            [badgeCellView sizeToFit];
            
            cellView = badgeCellView;
            
            break;
        }
            
        case RLMPropertyTypeBool: {
            RLMBoolTableCellView *boolCellView = [tableView makeViewWithIdentifier:@"BoolCell" owner:self];
            boolCellView.checkBox.state = [(NSNumber *)propertyValue boolValue] ? NSOnState : NSOffState;
            [boolCellView.checkBox setEnabled:!self.realmIsLocked];
            
            cellView = boolCellView;
            
            break;
        }
            // Intentional fallthrough
        case RLMPropertyTypeInt:
        case RLMPropertyTypeFloat:
        case RLMPropertyTypeDouble: {
            RLMNumberTableCellView *numberCellView = [tableView makeViewWithIdentifier:@"NumberCell" owner:self];
            numberCellView.textField.stringValue = [realmDescriptions printablePropertyValue:propertyValue ofType:type];
            numberCellView.textField.delegate = self;
            
            ((RLMNumberTextField *)numberCellView.textField).number = propertyValue;
            numberCellView.textField.editable = !self.realmIsLocked;
            
            cellView = numberCellView;
            
            break;
        }

        case RLMPropertyTypeObject: {
            RLMLinkTableCellView *linkCellView = [tableView makeViewWithIdentifier:@"LinkCell" owner:self];
            NSString *string = [realmDescriptions printablePropertyValue:propertyValue ofType:type];
            NSDictionary *attr = @{NSUnderlineStyleAttributeName : @(NSUnderlineStyleSingle)};
            linkCellView.textField.attributedStringValue = [[NSAttributedString alloc] initWithString:string attributes:attr];
            
            linkCellView.textField.editable = NO;
            
            cellView = linkCellView;

            break;
        }
            // Intentional fallthrough
        case RLMPropertyTypeData:
        case RLMPropertyTypeAny:
        case RLMPropertyTypeDate:
        case RLMPropertyTypeString: {
            RLMBasicTableCellView *basicCellView = [tableView makeViewWithIdentifier:@"BasicCell" owner:self];
            basicCellView.textField.stringValue = [realmDescriptions printablePropertyValue:propertyValue ofType:type];
            basicCellView.textField.delegate = self;
            basicCellView.textField.editable = !self.realmIsLocked && type != RLMPropertyTypeData;
            
            cellView = basicCellView;
            
            break;
        }
    }
    
    if (type != RLMPropertyTypeArray) {
        cellView.toolTip = [realmDescriptions tooltipForPropertyValue:propertyValue ofType:type];
    }

    return cellView;
}

#pragma mark - RLMTableView Delegate

// Asking the delegate about the state
- (BOOL)displaysArray
{
    return ([self.displayedType isMemberOfClass:[RLMArrayNode class]]);
}

// Asking the delegate about the contents
- (BOOL)containsObjectInRows:(NSIndexSet *)rowIndexes column:(NSInteger)column;
{
    if (column == -1) {
        return NO;
    }
    
    if ([self propertyTypeForColumn:column] != RLMPropertyTypeObject) {
        return NO;
    }

    NSInteger propertyIndex = [self propertyIndexForColumn:column];
   
    return [self cellsAreNonEmptyInRows:rowIndexes propertyColumn:propertyIndex];
}

- (BOOL)containsArrayInRows:(NSIndexSet *)rowIndexes column:(NSInteger)column;
{
    NSInteger propertyIndex = [self propertyIndexForColumn:column];
    
    if (column == -1) {
        return NO;
    }
    
    if ([self propertyTypeForColumn:column] != RLMPropertyTypeArray) {
        return NO;
    }
    
    return [self cellsAreNonEmptyInRows:rowIndexes propertyColumn:propertyIndex];
}

// RLMObject operations (when showing class table)
- (void)deleteObjects:(NSIndexSet *)rowIndexes
{
    [self deleteObjectsInRealmAtIndexes:rowIndexes];
    [self.parentWindowController reloadAllWindows];
}

- (void)addNewObjects:(NSIndexSet *)rowIndexes
{
    RLMRealm *realm = self.parentWindowController.modelDocument.presentedRealm.realm;

    NSMutableDictionary *objectBlueprint = [NSMutableDictionary dictionary];
    for (RLMProperty *property in self.displayedType.schema.properties) {
        objectBlueprint[property.name] = [self defaultValueForPropertyType:property.type];
    }
    
    NSUInteger objectCount = MAX(rowIndexes.count, 1);
    
    [realm beginWriteTransaction];
    for (NSUInteger i = 0; i < objectCount; i++) {
        [realm addObject: [realm createObject:self.displayedType.schema.className withObject:objectBlueprint]];
    }
    [realm commitWriteTransaction];
    
    [self.parentWindowController reloadAllWindows];
}

// RLMArray operations
- (void)removeRows:(NSIndexSet *)rowIndexes
{
    [self removeRowsInRealmAt:rowIndexes];
    [self.parentWindowController removeRowsInTableViewForArrayNode:(RLMArrayNode *)self.displayedType at:rowIndexes];
}

- (void)deleteRows:(NSIndexSet *)rowIndexes
{
    [self deleteRowsInRealmAt:rowIndexes];
    [self.parentWindowController deleteRowsInTableViewForArrayNode:(RLMArrayNode *)self.displayedType at:rowIndexes];
}

- (void)addNewRows:(NSIndexSet *)rowIndexes
{
    [self insertNewRowsInRealmAt:rowIndexes];
    [self.parentWindowController insertNewRowsInTableViewForArrayNode:(RLMArrayNode *)self.displayedType at:rowIndexes];
}

// Operations on links in cells
- (void)removeObjectLinksAtRows:(NSIndexSet *)rowIndexes column:(NSInteger)columnIndex
{
    [self removeContentsAtRows:rowIndexes column:columnIndex];
}

- (void)removeArrayLinksAtRows:(NSIndexSet *)rowIndexes column:(NSInteger)columnIndex
{
    [self removeContentsAtRows:rowIndexes column:columnIndex];
}

// Opening an array in a new window
- (void)openArrayInNewWindowAtRow:(NSInteger)row column:(NSInteger)column
{
    NSInteger propertyIndex = [self propertyIndexForColumn:column];
    RLMClassProperty *propertyNode = self.displayedType.propertyColumns[propertyIndex];
    RLMArrayNavigationState *state = [[RLMArrayNavigationState alloc] initWithSelectedType:self.displayedType
                                                                                 typeIndex:row
                                                                                  property:propertyNode.property
                                                                                arrayIndex:0];
    
    [self.parentWindowController newWindowWithNavigationState:state];
}

#pragma mark - Private Methods - RLMTableView Delegate Helpers

- (NSDictionary *)defaultValuesForProperties:(NSArray *)properties
{
    NSMutableDictionary *defaultValues = [NSMutableDictionary dictionary];
    
    for (RLMProperty *property in properties) {
        defaultValues[property.name] = [self defaultValueForPropertyType:property.type];
    }
    
    return defaultValues;
}

- (id)defaultValueForPropertyType:(RLMPropertyType)propertyType
{
    switch (propertyType) {
        case RLMPropertyTypeInt:
            return @0;
        
        case RLMPropertyTypeFloat:
            return @(0.0f);

        case RLMPropertyTypeDouble:
            return @0.0;
            
        case RLMPropertyTypeString:
            return @"";
            
        case RLMPropertyTypeBool:
            return @NO;
            
        case RLMPropertyTypeArray:
            return @[];
            
        case RLMPropertyTypeDate:
            return [NSDate date];
            
        case RLMPropertyTypeData:
            return [@"<Data>" dataUsingEncoding:NSUTF8StringEncoding];
            
        case RLMPropertyTypeAny:
            return @"<Any>";
            
        case RLMPropertyTypeObject: {
            return [NSNull null];
        }
    }
}

- (RLMPropertyType)propertyTypeForColumn:(NSInteger)column
{
    NSInteger propertyIndex = [self propertyIndexForColumn:column];

    RLMRealm *realm = self.parentWindowController.modelDocument.presentedRealm.realm;
    RLMObjectSchema *objectSchema = [realm.schema schemaForClassName:self.displayedType.name];
    RLMProperty *property = objectSchema.properties[propertyIndex];
    
    return property.type;
}

- (BOOL)cellsAreNonEmptyInRows:(NSIndexSet *)rowIndexes propertyColumn:(NSInteger)propertyColumn
{
    RLMClassProperty *classProperty = self.displayedType.propertyColumns[propertyColumn];
    
    __block BOOL returnValue = NO;
    
    [rowIndexes enumerateIndexesUsingBlock:^(NSUInteger rowIndex, BOOL *stop) {
        RLMObject *selectedInstance = [self.displayedType instanceAtIndex:rowIndex];
        id propertyValue = selectedInstance[classProperty.name];
        if (propertyValue) {
            returnValue = YES;
            *stop = YES;
        }
    }];
    
    return returnValue;
}

- (void)removeContentsAtRows:(NSIndexSet *)rowIndexes column:(NSInteger)column
{
    NSInteger propertyIndex = [self propertyIndexForColumn:column];
    
    RLMRealm *realm = self.parentWindowController.modelDocument.presentedRealm.realm;
    RLMClassProperty *classProperty = self.displayedType.propertyColumns[propertyIndex];
    
    id newValue = [NSNull null];
    if (classProperty.property.type == RLMPropertyTypeArray) {
        newValue = @[];
    }
    
    [realm beginWriteTransaction];
    [rowIndexes enumerateIndexesUsingBlock:^(NSUInteger rowIndex, BOOL *stop) {
        RLMObject *selectedInstance = [self.displayedType instanceAtIndex:rowIndex];
        selectedInstance[classProperty.name] = newValue;
    }];
    [realm commitWriteTransaction];
    
    [self.parentWindowController reloadAllWindows];
}

#pragma mark - Rearranging objects in arrays - Public methods

- (void)removeRowsInTableViewForArrayNode:(RLMArrayNode *)arrayNode at:(NSIndexSet *)rowIndexes
{
    // Check if this window is showing the arraynode that is to be rearranged visually
    if ([self.displayedType isEqualTo:arrayNode]) {
        [self removeRowsInTableViewAt:rowIndexes];
    }
}

- (void)deleteRowsInTableViewForArrayNode:(RLMArrayNode *)arrayNode at:(NSIndexSet *)rowIndexes
{
    // Check if this window is showing the arraynode that is to be rearranged visually
    if ([self.displayedType isEqualTo:arrayNode]) {
        [self deleteRowsInTableViewAt:rowIndexes];
    }
}

- (void)insertNewRowsInTableViewForArrayNode:(RLMArrayNode *)arrayNode at:(NSIndexSet *)rowIndexes
{
    // Check if this window is showing the arraynode that is to be rearranged visually
    if ([self.displayedType isEqualTo:arrayNode]) {
        [self insertNewRowsInTableViewAt:rowIndexes];
    }
}

- (void)moveRowsInTableViewForArrayNode:(RLMArrayNode *)arrayNode from:(NSIndexSet *)indexes to:(NSUInteger)destination
{
    // Check if this window is showing the arraynode that is to be rearranged visually
    if ([self.displayedType isEqualTo:arrayNode]) {
        [self moveRowsInTableViewFrom:indexes to:destination];
    }
}

#pragma mark - Rearranging objects in arrays - Private methods

// Removing
- (void)removeRowsInRealmAt:(NSIndexSet *)rowIndexes
{
    RLMRealm *realm = self.parentWindowController.modelDocument.presentedRealm.realm;
    
    [realm beginWriteTransaction];
    [rowIndexes enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger index, BOOL *stop) {
        [(RLMArrayNode *)self.displayedType removeInstanceAtIndex:index];
    }];
    [realm commitWriteTransaction];
}

- (void)removeRowsInTableViewAt:(NSIndexSet *)rowIndexes
{
    [self removeRowsInTableViewAtIndexes:rowIndexes];
}

// Deleting
- (void)deleteRowsInRealmAt:(NSIndexSet *)rowIndexes
{
    [self deleteObjectsInRealmAtIndexes:rowIndexes];
}

- (void)deleteRowsInTableViewAt:(NSIndexSet *)rowIndexes
{
    [self removeRowsInTableViewAtIndexes:rowIndexes];
}

// Inserting
- (void)insertNewRowsInRealmAt:(NSIndexSet *)rowIndexes
{
    if (rowIndexes.count == 0) {
        rowIndexes = [NSIndexSet indexSetWithIndex:0];
    }
    
    RLMRealm *realm = self.parentWindowController.modelDocument.presentedRealm.realm;
    
    NSMutableDictionary *objectBlueprint = [NSMutableDictionary dictionary];
    for (RLMProperty *property in self.displayedType.schema.properties) {
        objectBlueprint[property.name] = [self defaultValueForPropertyType:property.type];
    }
    
    [realm beginWriteTransaction];
    
    [rowIndexes enumerateRangesWithOptions:NSEnumerationReverse usingBlock:^(NSRange range, BOOL *stop) {
        for (NSUInteger i = range.location; i < NSMaxRange(range); i++) {
            RLMObject *object = [realm createObject:self.displayedType.schema.className withObject:objectBlueprint];
            [(RLMArrayNode *)self.displayedType insertInstance:object atIndex:range.location];
        }
    }];
    
    [realm commitWriteTransaction];
}

- (void)insertNewRowsInTableViewAt:(NSIndexSet *)rowIndexes
{
    if (rowIndexes.count == 0) {
        rowIndexes = [NSIndexSet indexSetWithIndex:0];
    }
    
    [self.tableView beginUpdates];
    
    [rowIndexes enumerateRangesWithOptions:NSEnumerationReverse usingBlock:^(NSRange range, BOOL *stop) {
        NSIndexSet *indexSetForRange = [NSIndexSet indexSetWithIndexesInRange:range];
        [self.tableView insertRowsAtIndexes:indexSetForRange withAnimation:NSTableViewAnimationEffectGap];
    }];
    
    [self.tableView endUpdates];
    [self updateArrayIndexColumn];
}

// Moving
- (void)moveRowsInRealmFrom:(NSIndexSet *)sourceIndexes to:(NSUInteger)destination
{
    [self moveRowsFrom:sourceIndexes to:destination updating:RLMUpdateTypeRealm];
}

- (void)moveRowsInTableViewFrom:(NSIndexSet *)sourceIndexes to:(NSUInteger)destination
{
    [self moveRowsFrom:sourceIndexes to:destination updating:RLMUpdateTypeTableView];
}

#pragma mark - Rearranging objects - Helper methods

-(void)updateArrayIndexColumn
{
    for (NSUInteger k = 0; k < self.tableView.numberOfRows; k++) {
        NSTableRowView *rowView = [self.tableView rowViewAtRow:k makeIfNecessary:NO];
        RLMTableCellView *cell = [rowView viewAtColumn:0];
        cell.textField.stringValue = [@(k) stringValue];
    }
}

- (void)removeRowsInTableViewAtIndexes:(NSIndexSet *)rowIndexes
{
    [self.tableView deselectAll:self];
    [self.tableView removeRowsAtIndexes:rowIndexes withAnimation:NSTableViewAnimationEffectGap];
    [self updateArrayIndexColumn];
}

- (void)deleteObjectsInRealmAtIndexes:(NSIndexSet *)rowIndexes
{
    RLMRealm *realm = self.parentWindowController.modelDocument.presentedRealm.realm;
    
    NSMutableArray *objectsToDelete = [NSMutableArray array];
    [rowIndexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
        [objectsToDelete addObject:[self.displayedType instanceAtIndex:index]];
    }];
    
    [realm beginWriteTransaction];
    [realm deleteObjects:objectsToDelete];
    [realm commitWriteTransaction];
}

// This method handles updating both realm and tableview, because there is a lot of shared logic.
- (void)moveRowsFrom:(NSIndexSet *)sourceIndexes to:(NSUInteger)destination updating:(RLMUpdateType)updateType
{
    RLMRealm *realm = self.parentWindowController.modelDocument.presentedRealm.realm;
    
    // Move indexset into mutable array
    NSMutableArray *sources = [NSMutableArray array];
    [sourceIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        [sources addObject:@(idx)];
    }];
    
    if (updateType == RLMUpdateTypeRealm) {
        [realm beginWriteTransaction];
    }
    else {
        [self.tableView beginUpdates];
    }
    
    // Iterate through the array, representing source row indices
    for (NSUInteger i = 0; i < sources.count; i++) {
        NSUInteger source = [sources[i] unsignedIntegerValue];
        
        // Perform the move
        if (updateType == RLMUpdateTypeRealm) {
            [(RLMArrayNode *)self.displayedType moveInstanceFromIndex:source toIndex:destination];
        }
        else {
            NSInteger tableViewDestination = destination > source ? destination - 1 : destination;
            [self.tableView moveRowAtIndex:source toIndex:tableViewDestination];
        }
        
        // Iterate through the remaining source row indices in the array
        for (NSUInteger j = i + 1; j < sources.count; j++) {
            NSUInteger sourceIndexToModify = [sources[j] unsignedIntegerValue];
            // Everything right of the destination is shifted right
            if (sourceIndexToModify > destination) {
                sourceIndexToModify++;
            }
            // Everything right of the current source is shifted left
            if (sourceIndexToModify > source) {
                sourceIndexToModify--;
            }
            sources[j] = @(sourceIndexToModify);
        }
        // If the move was from higher index to lower, shift destination right
        if (source > destination) {
            destination++;
        }
    }
    
    if (updateType == RLMUpdateTypeRealm) {
        [realm commitWriteTransaction];
    }
    else {
        [self.tableView endUpdates];
        [self updateArrayIndexColumn];
    }
}

#pragma mark - RLMTableView Delegate Methods - Mouse Handling

- (void)mouseDidEnterCellAtLocation:(RLMTableLocation)location
{
    NSInteger propertyIndex = [self propertyIndexForColumn:location.column];
    
    if (propertyIndex >= self.displayedType.propertyColumns.count || location.row >= self.displayedType.instanceCount) {
        [self disableLinkCursor];
        return;
    }
        
    RLMClassProperty *propertyNode = self.displayedType.propertyColumns[propertyIndex];
        
    RLMObject *selectedInstance = [self.displayedType instanceAtIndex:location.row];
    id propertyValue = selectedInstance[propertyNode.name];

    if (!propertyValue) {
        [self disableLinkCursor];
        [self mouseDidLeaveCellOrView];
        return;
    }

    if (propertyNode.type == RLMPropertyTypeObject) {
        [self enableLinkCursor];
    }
    else if (propertyNode.type == RLMPropertyTypeArray) {
        [self enableLinkCursor];
        [self updatePopupLocation:location];
        [self showPopupWindowAfterDelay];
    }
}

- (void)mouseDidExitCellAtLocation:(RLMTableLocation)location
{
    [self mouseDidLeaveCellOrView];
}

- (void)mouseDidExitView:(RLMTableView *)view
{
    [self mouseDidLeaveCellOrView];
}

- (BOOL)mouseIsInPopup
{
    NSPoint mouse = [NSEvent mouseLocation];
    return [NSWindow windowNumberAtPoint:mouse belowWindowWithWindowNumber:0] == self.popupController.view.window.windowNumber;
}

-(void)mouseDidLeaveCellOrView
{
    if (self.popupController.showingWindow && ![self mouseIsInPopup]) {
        [self hidePopupWindowAfterDelay];
    }
    [self disableLinkCursor];
}

#pragma mark - Private Methods - Mouse Handling

- (void)updatePopupLocation:(RLMTableLocation)location
{
    RLMRealm *realm = self.parentWindowController.modelDocument.presentedRealm.realm;
    
    NSInteger propertyIndex = [self propertyIndexForColumn:location.column];
    RLMClassProperty *propertyNode = self.displayedType.propertyColumns[propertyIndex];
    RLMObject *referringInstance = [self.displayedType instanceAtIndex:location.row];
    RLMArrayNode *arrayNode = [[RLMArrayNode alloc] initWithReferringProperty:propertyNode.property
                                                                     onObject:referringInstance
                                                                        realm:realm];
    
    NSRect cellFrame = [self.tableView frameOfCellAtColumn:location.column row:location.row];
    cellFrame = [self.tableView convertRect:cellFrame toView:nil];
    cellFrame = [self.tableView.window convertRectToScreen:cellFrame];
    
    NSPoint cellCenter = NSMakePoint(NSMidX(cellFrame), NSMidY(cellFrame));
    self.popupController.arrayNode = arrayNode;
    self.popupController.displayPoint = cellCenter;
}

-(void)hidePopupWindowAfterDelay
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showPopupWindow) object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hidePopupWindow) object:nil];
    [self performSelector:@selector(hidePopupWindow) withObject:nil afterDelay:0.1];
}

-(void)hidePopupWindow
{
    [self.popupController hideWindow];
}

-(void)showPopupWindowAfterDelay
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showPopupWindow) object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hidePopupWindow) object:nil];
    CGFloat delay = self.popupController.showingWindow ? 0.1 : 0.25;
    [self performSelector:@selector(showPopupWindow) withObject:nil afterDelay:delay];
    self.popupController.showingWindow = YES;
}

-(void)showPopupWindow
{
    [self.popupController showWindow];
    [self.popupController updateTableView];
}

#pragma mark - Public Methods - NSTableView Event Handling

- (IBAction)editedTextField:(NSTextField *)sender {
    NSInteger row = [self.tableView rowForView:sender];
    NSInteger column = [self.tableView columnForView:sender];
    NSInteger propertyIndex = [self propertyIndexForColumn:column];

    RLMTypeNode *displayedType = self.displayedType;
    RLMClassProperty *propertyNode = displayedType.propertyColumns[propertyIndex];
    RLMObject *selectedInstance = [displayedType instanceAtIndex:row];
    
    id result = nil;
    
    switch (propertyNode.type) {
        case RLMPropertyTypeInt:
            numberFormatter.allowsFloats = NO;
            result = [numberFormatter numberFromString:sender.stringValue];
            break;
            
        case RLMPropertyTypeFloat:
        case RLMPropertyTypeDouble:
            numberFormatter.allowsFloats = YES;
            numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
            result = [numberFormatter numberFromString:sender.stringValue];
            break;
            
        case RLMPropertyTypeString:
            result = sender.stringValue;
            break;

        case RLMPropertyTypeDate:
            result = [dateFormatter dateFromString:sender.stringValue];
            break;
            
        case RLMPropertyTypeAny:
        case RLMPropertyTypeArray:
        case RLMPropertyTypeBool:
        case RLMPropertyTypeData:
        case RLMPropertyTypeObject:
            break;
    }
    
    if (result) {
        RLMRealm *realm = self.parentWindowController.modelDocument.presentedRealm.realm;
        [realm beginWriteTransaction];
        selectedInstance[propertyNode.name] = result;
        [realm commitWriteTransaction];
    }
    
    [self.parentWindowController reloadAllWindows];
}

- (IBAction)editedCheckBox:(NSButton *)sender
{
    NSInteger row = [self.tableView rowForView:sender];
    NSInteger column = [self.tableView columnForView:sender];
    NSInteger propertyIndex = [self propertyIndexForColumn:column];

    RLMTypeNode *displayedType = self.displayedType;
    RLMClassProperty *propertyNode = displayedType.propertyColumns[propertyIndex];
    RLMObject *selectedInstance = [displayedType instanceAtIndex:row];

    NSNumber *result = @((BOOL)(sender.state == NSOnState));

    RLMRealm *realm = self.parentWindowController.modelDocument.presentedRealm.realm;
    [realm beginWriteTransaction];
    selectedInstance[propertyNode.name] = result;
    [realm commitWriteTransaction];
    
    [self.parentWindowController reloadAllWindows];
}

- (void)rightClickedLocation:(RLMTableLocation)location
{
    [self mouseDidLeaveCellOrView];

    NSUInteger row = location.row;

    if (row >= self.displayedType.instanceCount || RLMTableLocationRowIsUndefined(location)) {
        [self clearSelection];
        return;
    }
    
    if ([self.tableView.selectedRowIndexes containsIndex:row]) {
        return;
    }
    
    [self setSelectionIndex:row];
}

- (void)userClicked:(NSTableView *)sender
{
    [self mouseDidLeaveCellOrView];

    if (self.tableView.selectedRowIndexes.count > 1) {
        return;
    }
    
    NSInteger row = self.tableView.clickedRow;
    NSInteger column = self.tableView.clickedColumn;
    NSInteger propertyIndex = [self propertyIndexForColumn:column];
    
    if (row == -1 || propertyIndex < 0) {
        return;
    }
    
    RLMClassProperty *propertyNode = self.displayedType.propertyColumns[propertyIndex];
    
    if (propertyNode.type == RLMPropertyTypeObject) {
        RLMObject *selectedInstance = [self.displayedType instanceAtIndex:row];
        id propertyValue = selectedInstance[propertyNode.name];
        
        if ([propertyValue isKindOfClass:[RLMObject class]]) {
            RLMObject *linkedObject = (RLMObject *)propertyValue;
            RLMObjectSchema *linkedObjectSchema = linkedObject.objectSchema;
            
            for (RLMClassNode *classNode in self.parentWindowController.modelDocument.presentedRealm.topLevelClasses) {
                if ([classNode.name isEqualToString:linkedObjectSchema.className]) {
                    RLMResults *allInstances = [linkedObject.realm allObjects:linkedObjectSchema.className];
                    NSUInteger objectIndex = [allInstances indexOfObject:linkedObject];
                    
                    RLMNavigationState *state = [[RLMNavigationState alloc] initWithSelectedType:classNode index:objectIndex];
                    [self.parentWindowController addNavigationState:state fromViewController:self];
                    
                    break;
                }
            }
        }
    }
    else if (propertyNode.type == RLMPropertyTypeArray) {
        RLMObject *selectedInstance = [self.displayedType instanceAtIndex:row];
        NSObject *propertyValue = selectedInstance[propertyNode.name];
        
        if ([propertyValue isKindOfClass:[RLMArray class]]) {
            RLMArrayNavigationState *state = [[RLMArrayNavigationState alloc] initWithSelectedType:self.displayedType
                                                                                         typeIndex:row
                                                                                          property:propertyNode.property
                                                                                        arrayIndex:0];
            [self.parentWindowController addNavigationState:state fromViewController:self];
        }
    }
    else {
        [self setSelectionIndex:row];
    }
}

- (void)userDoubleClicked:(NSTableView *)sender {
    NSInteger row = self.tableView.clickedRow;
    NSInteger column = self.tableView.clickedColumn;
    NSInteger propertyIndex = [self propertyIndexForColumn:column];
    
    if (row == -1 || propertyIndex < 0 || self.realmIsLocked) {
        return;
    }
    
    RLMTypeNode *displayedType = self.displayedType;
    RLMClassProperty *propertyNode = displayedType.propertyColumns[propertyIndex];
    RLMObject *selectedObject = [displayedType instanceAtIndex:row];
    id propertyValue = selectedObject[propertyNode.name];
    
    switch (propertyNode.type) {
        case RLMPropertyTypeDate: {
            // Create a menu with a single menu item, and later populate it with the propertyValue
            NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""];
            
            NSSize intercellSpacing = [self.tableView intercellSpacing];
            NSRect frame = [self.tableView frameOfCellAtColumn:column row:row];
            frame.origin.x -= 0.5*intercellSpacing.width;
            frame.origin.y -= 0.5*intercellSpacing.height;
            frame.size.width += intercellSpacing.width;
            frame.size.height += intercellSpacing.height;
            
            frame.size.height = MAX(23.0, frame.size.height);
            
            // Set up a date picker with no border or background
            NSDatePicker *datepicker = [[NSDatePicker alloc] initWithFrame:frame];
            datepicker.bordered = NO;
            datepicker.drawsBackground = NO;
            datepicker.datePickerStyle = NSTextFieldAndStepperDatePickerStyle;
            datepicker.datePickerElements = NSHourMinuteSecondDatePickerElementFlag
              | NSYearMonthDayDatePickerElementFlag | NSTimeZoneDatePickerElementFlag;
            datepicker.dateValue = propertyValue;
            
            item.view = datepicker;
            [menu addItem:item];
            
            if ([menu popUpMenuPositioningItem:nil atLocation:frame.origin inView:self.tableView]) {
                RLMRealm *realm = self.parentWindowController.modelDocument.presentedRealm.realm;
                [realm beginWriteTransaction];
                selectedObject[propertyNode.name] = datepicker.dateValue;
                [realm commitWriteTransaction];
                [self.tableView reloadData];
            }
            break;
        }
            
        case RLMPropertyTypeInt:
        case RLMPropertyTypeFloat:
        case RLMPropertyTypeDouble:
        case RLMPropertyTypeString: {
            // Start editing the textfield
            NSTableCellView *cellView = [self.tableView viewAtColumn:column row:row makeIfNecessary:NO];
            [[cellView.textField window] makeFirstResponder:cellView.textField];
            break;
        }
        case RLMPropertyTypeAny:
        case RLMPropertyTypeArray:
        case RLMPropertyTypeBool:
        case RLMPropertyTypeData:
        case RLMPropertyTypeObject:
            // Do nothing
            break;
    }
}

#pragma mark - Public Methods - Table View Construction

- (void)enableLinkCursor
{
    if (linkCursorDisplaying) {
        return;
    }
    NSCursor *currentCursor = [NSCursor currentCursor];
    [currentCursor push];
    
    NSCursor *newCursor = [NSCursor pointingHandCursor];
    [newCursor set];
    
    linkCursorDisplaying = YES;
}

- (void)disableLinkCursor
{
    if (!linkCursorDisplaying) {
        return;
    }
    
    [NSCursor pop];
    linkCursorDisplaying = NO;
}

#pragma mark - Private Methods - Convenience

-(NSInteger)propertyIndexForColumn:(NSInteger)column
{
    return self.displaysArray ? column - 1 : column;
}

@end

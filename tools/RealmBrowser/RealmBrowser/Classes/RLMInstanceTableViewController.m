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

NSString * const kRLMObjectType = @"RLMObjectType";

const NSUInteger kMaxNumberOfArrayEntriesInToolTip = 5;
const NSUInteger kMaxNumberOfStringCharsInObjectLink = 20;
const NSUInteger kMaxNumberOfStringCharsForTooltip = 300;
const NSUInteger kMaxNumberOfInlineStringCharsForTooltip = 20;
const NSUInteger kMaxNumberOfObjectCharsForTable = 200;
const NSUInteger kMaxDepthForTooltips = 2;

@interface RLMObject ()

- (instancetype)initWithRealm:(RLMRealm *)realm
                       schema:(RLMObjectSchema *)schema
                defaultValues:(BOOL)useDefaults;

@end

@implementation RLMInstanceTableViewController {
    BOOL awake;
    BOOL linkCursorDisplaying;
    NSDateFormatter *dateFormatter;
    NSNumberFormatter *numberFormatter;
    NSMutableDictionary *autofittedColumns;
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
    
    [self.tableView registerForDraggedTypes:@[kRLMObjectType]];
    [self.tableView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];

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
        [self.realmTableView setupColumnsWithType:newState.selectedType
                               withSelectionAtRow:newState.selectedInstanceIndex];
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
        [self.realmTableView setupColumnsWithType:arrayNode withSelectionAtRow:0];
        [self setSelectionIndex:arrayState.arrayIndex];
    }
    else if ([newState isMemberOfClass:[RLMQueryNavigationState class]]) {
        RLMQueryNavigationState *arrayState = (RLMQueryNavigationState *)newState;
        
        RLMArrayNode *arrayNode = [[RLMArrayNode alloc] initWithQuery:arrayState.searchText
                                                               result:arrayState.results
                                                            andParent:arrayState.selectedType];
        self.displayedType = arrayNode;
        [self.realmTableView setupColumnsWithType:arrayNode withSelectionAtRow:0];
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
        
        [self.parentWindowController moveRowsInArrayNode:(RLMArrayNode *)self.displayedType from:rowIndexes to:destination];
        [self moveRowsInRealmFrom:rowIndexes to:destination];
        
        return YES;
    }
    
    return NO;
}

- (void)moveRowsInArrayNode:(RLMArrayNode *)arrayNode from:(NSIndexSet *)sourceIndexes to:(NSUInteger)destination
{
    if (self.displaysArray && [self.displayedType isEqualTo:arrayNode]) {
        [self moveRowsFrom:sourceIndexes to:destination inRealm:NO];
    }
}

- (void)moveRowsInRealmFrom:(NSIndexSet *)sourceIndexes to:(NSUInteger)destination
{
    [self moveRowsFrom:sourceIndexes to:destination inRealm:YES];
}

- (void)moveRowsFrom:(NSIndexSet *)sourceIndexes to:(NSUInteger)destination inRealm:(BOOL)inRealm
{
    RLMRealm *realm = self.parentWindowController.modelDocument.presentedRealm.realm;
    
    // Move indexset into mutable array
    NSMutableArray *sources = [NSMutableArray array];
    [sourceIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        [sources addObject:@(idx)];
    }];
    
    if (inRealm) {
        [realm beginWriteTransaction];
    }
    else {
        [self.tableView beginUpdates];
    }
    
    // Iterate through the array, representing source row indices
    for (NSUInteger i = 0; i < sources.count; i++) {
        NSUInteger source = [sources[i] unsignedIntegerValue];
        
        // Perform the move
        if (inRealm) {
            [(RLMArrayNode *)self.displayedType moveInstanceFromIndex:source toIndex:destination];
        }
        else {
            NSInteger tableViewDestination = destination > source ? destination - 1 : destination;
            [self.tableView moveRowAtIndex:source toIndex:tableViewDestination];
        }
        
        //Iterate through the remaining source row indices in the array
        for (NSUInteger j = i + 1; j < sources.count; j++) {
            NSUInteger sourceIndexToModify = [sources[j] unsignedIntegerValue];
            // Everything right of the destination is shifted right
            if (sourceIndexToModify > destination) {
                sources[j] = @([sources[j] unsignedIntegerValue] + 1);
            }
            // Everything right of the current source is shifted left
            if (sourceIndexToModify > source) {
                sources[j] = @([sources[j] unsignedIntegerValue] - 1);
            }
        }
        // If the move was from higher index to lower, shift destination right
        if (source > destination) {
            destination++;
        }
    }
    
    if (inRealm) {
        [realm commitWriteTransaction];
    }
    else {
        [self.tableView endUpdates];
        
        // Recalculate the row indices in the zeroth column
        for (NSUInteger k = 0; k < self.tableView.numberOfRows; k++) {
            NSTableRowView *rowView = [self.tableView rowViewAtRow:k makeIfNecessary:NO];
            RLMTableCellView *cell = [rowView viewAtColumn:0];
            cell.textField.stringValue = [@(k) stringValue];
        }
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    if (tableView != self.tableView) {
        return 0;
    }
    
    return self.displayedType.instanceCount;
}

#pragma mark - RLMTableView Data Source

-(NSString *)headerToolTipForColumn:(RLMClassProperty *)propertyColumn
{
    NSString *toolTip;
    
    switch (propertyColumn.property.type) {
        case RLMPropertyTypeBool:
            return @"Boolean";
        case RLMPropertyTypeInt:
            return @"Integer";
        case RLMPropertyTypeFloat:
            return @"Float";
        case RLMPropertyTypeDouble:
            return @"Double";
        case RLMPropertyTypeString:
            return @"String";
        case RLMPropertyTypeData:
            return @"Data";
        case RLMPropertyTypeAny:
            return @"Any";
        case RLMPropertyTypeDate:
            return @"Date";
        case RLMPropertyTypeArray:
            return [NSString stringWithFormat:@"%@[]", propertyColumn.property.objectClassName];
        case RLMPropertyTypeObject:
            return [NSString stringWithFormat:@"%@", propertyColumn.property.objectClassName];
    }
    
    return toolTip;
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
            NSString *string = [self printablePropertyValue:propertyValue ofType:type];
            NSDictionary *attr = @{NSUnderlineStyleAttributeName : @(NSUnderlineStyleSingle)};
            badgeCellView.textField.attributedStringValue = [[NSAttributedString alloc] initWithString:string attributes:attr];
            
            badgeCellView.textField.editable = NO;

            badgeCellView.badge.hidden = NO;
            badgeCellView.badge.title = [NSString stringWithFormat:@"%lu", [(RLMArray *)propertyValue count]];
            [badgeCellView.badge.cell setHighlightsBy:0];
            
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
            numberCellView.textField.stringValue = [self printablePropertyValue:propertyValue ofType:type];
            numberCellView.textField.delegate = self;
            
            ((RLMNumberTextField *)numberCellView.textField).number = propertyValue;
            numberCellView.textField.editable = !self.realmIsLocked;
            
            cellView = numberCellView;
            
            break;
        }

        case RLMPropertyTypeObject: {
            RLMLinkTableCellView *linkCellView = [tableView makeViewWithIdentifier:@"LinkCell" owner:self];
            NSString *string = [self printablePropertyValue:propertyValue ofType:type];
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
            basicCellView.textField.stringValue = [self printablePropertyValue:propertyValue ofType:type];
            basicCellView.textField.delegate = self;
            basicCellView.textField.editable = !self.realmIsLocked && type != RLMPropertyTypeData;
            
            cellView = basicCellView;
            
            break;
        }
    }
    
    cellView.toolTip = [self tooltipForPropertyValue:propertyValue ofType:type];
    
    return cellView;
}

#pragma mark - Private Methods - NSTableView Delegate

-(NSString *)printablePropertyValue:(id)propertyValue ofType:(RLMPropertyType)propertyType
{
    return [self printablePropertyValue:propertyValue ofType:propertyType linkFormat:NO];
}

-(NSString *)printablePropertyValue:(id)propertyValue ofType:(RLMPropertyType)propertyType linkFormat:(BOOL)linkFormat
{
    if (!propertyValue) {
        return @"";
    }
    
    switch (propertyType) {
        case RLMPropertyTypeInt:
            numberFormatter.minimumFractionDigits = 0;
            
            return [numberFormatter stringFromNumber:(NSNumber *)propertyValue];

            // Intentional fallthrough
        case RLMPropertyTypeFloat:
        case RLMPropertyTypeDouble:
            numberFormatter.minimumFractionDigits = 3;
            numberFormatter.maximumFractionDigits = 3;
            
            return [numberFormatter stringFromNumber:(NSNumber *)propertyValue];
            
        case RLMPropertyTypeString: {
            NSString *stringValue = propertyValue;
            
            if (linkFormat && stringValue.length > kMaxNumberOfStringCharsInObjectLink) {
                stringValue = [stringValue substringToIndex:kMaxNumberOfStringCharsInObjectLink - 3];
                stringValue = [stringValue stringByAppendingString:@"..."];
            }
            
            return stringValue;
        }
            
        case RLMPropertyTypeBool:
            return [(NSNumber *)propertyValue boolValue] ? @"TRUE" : @"FALSE";
            
        case RLMPropertyTypeArray: {
            RLMArray *referredArray = (RLMArray *)propertyValue;
            if (linkFormat) {
                return [NSString stringWithFormat:@"%@[%lu]", referredArray.objectClassName, referredArray.count];
            }
            
            return [NSString stringWithFormat:@"%@[]", referredArray.objectClassName];
        }
            
        case RLMPropertyTypeDate:
            return [dateFormatter stringFromDate:(NSDate *)propertyValue];
            
        case RLMPropertyTypeData:
            return @"<Data>";
            
        case RLMPropertyTypeAny:
            return @"<Any>";
            
        case RLMPropertyTypeObject: {
            RLMObject *referredObject = (RLMObject *)propertyValue;
            if (referredObject == nil) {
                return @"";
            }
            
            if (linkFormat) {
                return [NSString stringWithFormat:@"%@(...)", referredObject.objectSchema.className];
            }
            
            NSString *returnString = [NSString stringWithFormat:@"%@(", referredObject.objectSchema.className];
            
            for (RLMProperty *property in referredObject.objectSchema.properties) {
                id propertyValue = referredObject[property.name];
                NSString *propertyDescription = [self printablePropertyValue:propertyValue ofType:property.type linkFormat:YES];
                
                if (returnString.length > kMaxNumberOfObjectCharsForTable - 4) {
                    returnString = [returnString stringByAppendingFormat:@"..."];
                    break;
                }
                
                returnString = [returnString stringByAppendingFormat:@"%@, ", propertyDescription];
            }
            
            if ([returnString hasSuffix:@", "]) {
                returnString = [returnString substringToIndex:returnString.length - 2];
            }
            
            return [returnString stringByAppendingString:@")"];
        }
    }
}

-(NSString *)tooltipForPropertyValue:(id)propertyValue ofType:(RLMPropertyType)propertyType
{
    if (!propertyValue) {
        return nil;
    }

    switch (propertyType) {
        case RLMPropertyTypeString: {
            NSUInteger chars = MIN(kMaxNumberOfStringCharsForTooltip, [(NSString *)propertyValue length]);
            return [(NSString *)propertyValue substringToIndex:chars];
        }
            
        case RLMPropertyTypeFloat:
        case RLMPropertyTypeDouble:
            numberFormatter.minimumFractionDigits = 0;
            numberFormatter.maximumFractionDigits = UINT16_MAX;
            return [numberFormatter stringFromNumber:propertyValue];
            
        case RLMPropertyTypeObject:
            return [self tooltipForObject:(RLMObject *)propertyValue];
            
        case RLMPropertyTypeArray:
            return [self tooltipForArray:(RLMArray *)propertyValue];
            
        case RLMPropertyTypeAny:
        case RLMPropertyTypeBool:
        case RLMPropertyTypeData:
        case RLMPropertyTypeDate:
        case RLMPropertyTypeInt:
            return nil;
    }
}

- (NSString *)tooltipForObject:(RLMObject *)object
{
    return [self tooltipForObject:object withDepth:0];
}

- (NSString *)tooltipForObject:(RLMObject *)object withDepth:(NSUInteger)depth
{
    if (depth == kMaxDepthForTooltips) {
        return [object.objectSchema.className stringByAppendingString:@"(...)"];
    }
    
    NSMutableString *string = [NSMutableString stringWithFormat:@"%@:\n", object.objectSchema.className];
    NSString *tabs = [@"" stringByPaddingToLength:depth + 1 withString:@"\t" startingAtIndex:0];
    
    for (RLMProperty *property in object.objectSchema.properties) {
        id obj = object[property.name];
        
        NSString *sub;
        switch (property.type) {
            case RLMPropertyTypeArray:
                sub = [self tooltipForArray:obj withDepth:kMaxDepthForTooltips];
                break;
            case RLMPropertyTypeObject: {
                sub = [self tooltipForObject:obj withDepth:depth + 1];
                break;
            }
            default:
                sub = [self printablePropertyValue:obj ofType:property.type];

                if (property.type == RLMPropertyTypeString && sub.length > kMaxNumberOfInlineStringCharsForTooltip) {
                    sub = [sub substringToIndex:kMaxNumberOfInlineStringCharsForTooltip];
                    sub = [sub stringByAppendingString:@"..."];
                }
                break;
        }

        [string appendFormat:@"%@%@ = %@\n", tabs, property.name, sub];
    }
    
    return string;
}

- (NSString *)tooltipForArray:(RLMArray *)array
{
    return [self tooltipForArray:array withDepth:0];
}

- (NSString *)tooltipForArray:(RLMArray *)array withDepth:(NSUInteger)depth
{
    if (depth == kMaxDepthForTooltips) {
        return [array.objectClassName stringByAppendingFormat:@"[%lu]", array.count];
    }
    
    const NSUInteger maxObjects = 3;
    NSString *tabs = [@"" stringByPaddingToLength:depth withString:@"\t" startingAtIndex:0];
    NSMutableString *string = [NSMutableString stringWithFormat:@"%@%@[%lu]", tabs, array.objectClassName, array.count];
    
    if (array.count == 0) {
        return string;
    }
    [string appendString:@":\n"];
    
    NSUInteger index = 0;
    NSUInteger skipped = 0;
    for (id obj in array) {
        NSString *sub = [self tooltipForObject:obj withDepth:depth + 1];
        [string appendFormat:@"%@\t[%lu] %@\n", tabs, index++, sub];
        if (index >= maxObjects) {
            skipped = array.count - maxObjects;
            break;
        }
    }
    
    // Remove last comma and newline characters
    if (array.count > 0) {
        [string deleteCharactersInRange:NSMakeRange(string.length - 1, 1)];
    }
    if (skipped) {
        [string appendFormat:@"\n\t%@+%lu more", tabs, skipped];
    }
    [string appendFormat:@"\n"];
    
    return string;
}


#pragma mark - RLMTableView Delegate

- (void)addRows:(NSIndexSet *)rowIndexes
{
    if (self.realmIsLocked) {
        return;
    }
    
    RLMRealm *realm = self.parentWindowController.modelDocument.presentedRealm.realm;
    RLMObjectSchema *objectSchema = [realm.schema schemaForClassName:self.displayedType.name];
    
    [realm beginWriteTransaction];
    
    NSUInteger rowsToAdd = MAX(rowIndexes.count, 1);
    
    for (int i = 0; i < rowsToAdd; i++) {
        RLMObject *object = [[RLMObject alloc] initWithRealm:nil schema:objectSchema defaultValues:NO];

        [realm addObject:object];
        for (RLMProperty *property in objectSchema.properties) {
            object[property.name] = [self defaultValueForPropertyType:property.type];
        }
    }
    
    [realm commitWriteTransaction];
    [self.parentWindowController reloadAllWindows];
}

- (void)deleteRows:(NSIndexSet *)rowIndexes
{
    if (self.realmIsLocked) {
        return;
    }

    NSMutableArray *objectsToDelete = [NSMutableArray array];
    [rowIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        RLMObject *object = [self.displayedType instanceAtIndex:idx];
        [objectsToDelete addObject:object];
    }];
    
    RLMRealm *realm = self.parentWindowController.modelDocument.presentedRealm.realm;
    [realm beginWriteTransaction];
    [realm deleteObjects:objectsToDelete];
    [realm commitWriteTransaction];
    
    [self.parentWindowController reloadAllWindows];
}

- (void)insertRows:(NSIndexSet *)rowIndexes
{
    if (self.realmIsLocked || !self.displaysArray) {
        return;
    }

    RLMRealm *realm = self.parentWindowController.modelDocument.presentedRealm.realm;
    RLMTypeNode *displayedType = self.displayedType;
    RLMObjectSchema *objectSchema = displayedType.schema;
    
    NSUInteger rowsToInsert = MAX(rowIndexes.count, 1);
    NSUInteger rowToInsertAt = rowIndexes.firstIndex;
    
    if (rowToInsertAt == -1) {
        rowToInsertAt = 0;
    }
    
    [realm beginWriteTransaction];
    
    for (int i = 0; i < rowsToInsert; i++) {
        RLMObject *object = [[RLMObject alloc] initWithRealm:realm schema:objectSchema defaultValues:NO];
        
        for (RLMProperty *property in objectSchema.properties) {
            object[property.name] = [self defaultValueForPropertyType:property.type];
        }
        [(RLMArrayNode *)self.displayedType insertInstance:object atIndex:rowToInsertAt];
    }

    [realm commitWriteTransaction];
    
    [self.parentWindowController reloadAllWindows];
}

- (void)removeRows:(NSIndexSet *)rowIndexes
{
    if (self.realmIsLocked || !self.displaysArray) {
        return;
    }

    RLMRealm *realm = self.parentWindowController.modelDocument.presentedRealm.realm;
    [realm beginWriteTransaction];
    [rowIndexes enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger idx, BOOL *stop) {
        [(RLMArrayNode *)self.displayedType removeInstanceAtIndex:idx];
    }];
    [realm commitWriteTransaction];
    [self.parentWindowController reloadAllWindows];
}

- (BOOL)containsObjectInRows:(NSIndexSet *)rowIndexes column:(NSInteger)column;
{
    NSInteger propertyIndex = [self propertyIndexForColumn:column];

    if (column == -1) {
        return NO;
    }

    if ([self propertyTypeForColumn:column] != RLMPropertyTypeObject) {
        return NO;
    }
    
    return [self cellsAreNonEmptyInRows:rowIndexes propertyColumn:propertyIndex];
}

- (void)removeObjectLinksAtRows:(NSIndexSet *)rowIndexes column:(NSInteger)columnIndex
{
    [self removeContentsAtRows:rowIndexes column:columnIndex];
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

- (void)removeArrayLinksAtRows:(NSIndexSet *)rowIndexes column:(NSInteger)columnIndex
{
    [self removeContentsAtRows:rowIndexes column:columnIndex];
}

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

#pragma mark - Private Methods - RLMTableView Delegate

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
            return @"<Data>";
            
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

#pragma mark - Mouse Handling

- (void)mouseDidEnterCellAtLocation:(RLMTableLocation)location
{
    NSInteger propertyIndex = [self propertyIndexForColumn:location.column];
    
    if (propertyIndex >= self.displayedType.propertyColumns.count || location.row >= self.displayedType.instanceCount) {
        [self disableLinkCursor];
        return;
    }
    
    RLMClassProperty *propertyNode = self.displayedType.propertyColumns[propertyIndex];
    
    if (propertyNode.type == RLMPropertyTypeObject) {
        RLMObject *selectedInstance = [self.displayedType instanceAtIndex:location.row];
        NSObject *propertyValue = selectedInstance[propertyNode.name];
        
        if (propertyValue) {
            [self enableLinkCursor];
            return;
        }
    }
    else if (propertyNode.type == RLMPropertyTypeArray) {
        [self enableLinkCursor];
        return;
    }
    
    [self disableLinkCursor];
}

- (void)mouseDidExitCellAtLocation:(RLMTableLocation)location
{
    [self disableLinkCursor];
}

- (void)mouseDidExitView:(RLMTableView *)view
{
    [self disableLinkCursor];
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
    
    [self.tableView reloadData];
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
}

- (void)rightClickedLocation:(RLMTableLocation)location
{
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
                    RLMArray *allInstances = [linkedObject.realm allObjects:linkedObjectSchema.className];
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

#pragma mark - Private Methods - Setters/Getters

- (BOOL)displaysArray
{
    return ([self.displayedType isMemberOfClass:[RLMArrayNode class]]);
}

#pragma mark - Private Methods - Convenience

-(NSInteger)propertyIndexForColumn:(NSInteger)column
{
    return self.displaysArray ? column - 1 : column;
}


@end
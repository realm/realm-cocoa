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

#import "RLMViewController.h"

@implementation RLMViewController

#pragma mark - NSViewController overrides

- (void)setView:(NSView *)newValue
{
    [self viewWillLoad];
    [super setView:newValue];
    [self viewDidLoad];
}

- (void)loadView
{
    [self viewWillLoad];
    [super loadView];
    [self viewDidLoad];
}

#pragma mark - Public methods - Accessors

- (NSTableView *)tableView
{
    if ([self.view isKindOfClass:[NSTableView class]]) {
        return (NSTableView *)self.view;
    }
        
    return nil;
}

#pragma mark - Public methods

- (void)viewWillLoad
{
    // Empty default implementation - can be overridden by subclasses.
}

- (void)viewDidLoad
{
    // Empty default implementation - can be overridden by subclasses.    
}

@end

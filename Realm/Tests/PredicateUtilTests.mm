////////////////////////////////////////////////////////////////////////////
//
// Copyright 2016 Realm Inc.
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

#import "RLMTestCase.h"

#import "RLMPredicateUtil.hpp"

@interface PredicateUtilTests : RLMTestCase

@end

@implementation PredicateUtilTests

- (void)testVisitingAllExpressionTypes {
    auto testPredicate = [&](NSPredicate *predicate, size_t expectedExpressionCount) {
        static size_t visitCount;
        visitCount = 0;
        auto visitExpression = [](NSExpression *expression) {
            visitCount++;
            return expression;
        };
        NSPredicate *transformedPredicate = transformPredicate(predicate, visitExpression);
        XCTAssertEqualObjects(predicate, transformedPredicate);
        XCTAssertEqual(visitCount, expectedExpressionCount);
    };
    auto testPredicateString = [=](NSString *predicateString, size_t expectedExpressionCount) {
        return testPredicate([NSPredicate predicateWithFormat:predicateString], expectedExpressionCount);
    };

    testPredicateString(@"TRUEPREDICATE", 0);
    testPredicateString(@"A == B", 2);
    testPredicateString(@"A == B AND C == 1", 4);
    testPredicateString(@"A.@count == 2", 2);
    testPredicateString(@"SUBQUERY(collection, $variable, $variable.property == 1).@count > 2", 9);
    testPredicateString(@"A IN {1, 2, 3}", 5);
    testPredicateString(@"A IN B UNION C", 4);
    testPredicateString(@"A IN B INTERSECT C", 4);
    testPredicateString(@"A IN B MINUS C", 4);
    if ([NSExpression respondsToSelector:@selector(expressionForConditional:trueExpression:falseExpression:)]) {
        // Only test conditional predicates on platforms that support them (i.e. iOS 9 and later).
        testPredicateString(@"TERNARY(TRUEPREDICATE, A, B) == 1", 4);
    }
    testPredicateString(@"ANYKEY == 1", 2);
    testPredicateString(@"SELF == 1", 2);

    testPredicate([NSPredicate predicateWithBlock:^(id, NSDictionary*) { return NO; }], 0);

    auto block = ^(id, NSArray *, NSMutableDictionary *) {
        return @"Hello";
    };
    testPredicate([NSComparisonPredicate predicateWithLeftExpression:[NSExpression expressionForBlock:block arguments:nil]
                                                     rightExpression:[NSExpression expressionForConstantValue:@"hello"]
                                                            modifier:NSDirectPredicateModifier
                                                                type:NSEqualToPredicateOperatorType
                                                             options:0], 2);
}

@end

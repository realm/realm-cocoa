////////////////////////////////////////////////////////////////////////////
//
// TIGHTDB CONFIDENTIAL
// __________________
//
//  [2011] - [2014] TightDB Inc
//  All Rights Reserved.
//
// NOTICE:  All information contained herein is, and remains
// the property of TightDB Incorporated and its suppliers,
// if any.  The intellectual and technical concepts contained
// herein are proprietary to TightDB Incorporated
// and its suppliers and may be covered by U.S. and Foreign Patents,
// patents in process, and are protected by trade secret or copyright law.
// Dissemination of this information or reproduction of this material
// is strictly forbidden unless prior written permission is obtained
// from TightDB Incorporated.
//
////////////////////////////////////////////////////////////////////////////

#import <Foundation/Foundation.h>
#import "RLMUtil.h"
#import "NSData+RLMGetBinaryData.h"

inline bool nsnumber_is_like_bool(NSObject *obj)
{
    const char* data_type = [(NSNumber *)obj objCType];
    // @encode(BOOL) is 'B' on iOS 64 and 'c'
    // objcType is always 'c'. Therefore compare to "c".
    
    return data_type[0] == 'c';
}

inline bool nsnumber_is_like_integer(NSObject *obj)
{
    const char* data_type = [(NSNumber *)obj objCType];
    // FIXME: Performance optimization - don't use strcmp, use first char in data_type.
    return (strcmp(data_type, @encode(int)) == 0 ||
            strcmp(data_type, @encode(long)) ==  0 ||
            strcmp(data_type, @encode(long long)) == 0 ||
            strcmp(data_type, @encode(unsigned int)) == 0 ||
            strcmp(data_type, @encode(unsigned long)) == 0 ||
            strcmp(data_type, @encode(unsigned long long)) == 0);
}

inline bool nsnumber_is_like_float(NSObject *obj)
{
    const char* data_type = [(NSNumber *)obj objCType];
    // FIXME: Performance optimization - don't use strcmp, use first char in data_type.
    return (strcmp(data_type, @encode(float)) == 0 ||
            strcmp(data_type, @encode(int)) == 0 ||
            strcmp(data_type, @encode(long)) ==  0 ||
            strcmp(data_type, @encode(long long)) == 0 ||
            strcmp(data_type, @encode(unsigned int)) == 0 ||
            strcmp(data_type, @encode(unsigned long)) == 0 ||
            strcmp(data_type, @encode(unsigned long long)) == 0);
}

inline bool nsnumber_is_like_double(NSObject *obj)
{
    const char* data_type = [(NSNumber *)obj objCType];
    // FIXME: Performance optimization - don't use strcmp, use first char in data_type.
    return (strcmp(data_type, @encode(double)) == 0 ||
            strcmp(data_type, @encode(float)) == 0 ||
            strcmp(data_type, @encode(int)) == 0 ||
            strcmp(data_type, @encode(long)) ==  0 ||
            strcmp(data_type, @encode(long long)) == 0 ||
            strcmp(data_type, @encode(unsigned int)) == 0 ||
            strcmp(data_type, @encode(unsigned long)) == 0 ||
            strcmp(data_type, @encode(unsigned long long)) == 0);
}

BOOL RLMIsObjectOfType(id obj, RLMPropertyType type) {
    switch (type) {
        case RLMPropertyTypeString:
            return [obj isKindOfClass:[NSString class]];
        case RLMPropertyTypeBool:
            if ([obj isKindOfClass:[NSNumber class]]) {
                return nsnumber_is_like_bool(obj);
            }
            return NO;
        case RLMPropertyTypeDate:
            if ([obj isKindOfClass:[NSNumber class]]) {
                return nsnumber_is_like_integer(obj);
            }
            return [obj isKindOfClass:[NSDate class]];
        case RLMPropertyTypeInt:
            if ([obj isKindOfClass:[NSNumber class]]) {
                return nsnumber_is_like_integer(obj);
            }
            return NO;
        case RLMPropertyTypeFloat:
            if ([obj isKindOfClass:[NSNumber class]]) {
                return nsnumber_is_like_float(obj);
            }
            return NO;
        case RLMPropertyTypeDouble:
            if ([obj isKindOfClass:[NSNumber class]]) {
                return nsnumber_is_like_double(obj);
            }
            return NO;
        case RLMPropertyTypeData:
            return [obj isKindOfClass:[NSData class]];
        case RLMPropertyTypeNone:
            break;

        // FIXME: missing entries
        case RLMPropertyTypeObject:
        case RLMPropertyTypeTable:
        case RLMPropertyTypeAny:
            break;
    }
    @throw [NSException exceptionWithName:@"RLMException" reason:@"Invalid RLMPropertyType specified" userInfo:nil];
}


void RLMSetAnyProperty(tightdb::Table &table, NSUInteger row_ndx, NSUInteger col_ndx, id obj) {
//    if (obj == nil) {
//        table.nullify_link(col_ndx, row_ndx);
//        return;
//    }
    if ([obj isKindOfClass:[NSString class]]) {
        tightdb::StringData sd([(NSString *)obj UTF8String]);
        table.set_mixed(col_ndx, row_ndx, sd);
        return;
    }
    if ([obj isKindOfClass:[NSDate class]]) {
        table.set_mixed(col_ndx, row_ndx, tightdb::DateTime(time_t([(NSDate *)obj timeIntervalSince1970])));
        return;
    }
    if ([obj isKindOfClass:[NSData class]]) {
        table.set_mixed(col_ndx, row_ndx, ((NSData *)obj).rlmBinaryData);
        return;
    }
    if ([obj isKindOfClass:[NSNumber class]]) {
        const char *data_type = [(NSNumber *)obj objCType];
        const char dt = data_type[0];
        switch (dt) {
            case 'i':
            case 's':
            case 'l':
                table.set_mixed(col_ndx, row_ndx, (int64_t)[(NSNumber *)obj longValue]);
                return;
            case 'f':
                table.set_mixed(col_ndx, row_ndx, [(NSNumber *)obj floatValue]);
                return;
            case 'd':
                table.set_mixed(col_ndx, row_ndx, [(NSNumber *)obj doubleValue]);
                return;
            case 'B':
            case 'c':
                table.set_mixed(col_ndx, row_ndx, [(NSNumber *)obj boolValue] == YES);
                return;
        }
    }
    @throw [NSException exceptionWithName:@"RLMException" reason:@"Inserting invalid object for RLMPropertyTypeAny property" userInfo:nil];
}

id RLMGetAnyProperty(tightdb::Table &table, NSUInteger row_ndx, NSUInteger col_ndx) {
    tightdb::Mixed mixed = table.get_mixed(col_ndx, row_ndx);
    switch (mixed.get_type()) {
        case RLMPropertyTypeString:
            return [NSString stringWithUTF8String:mixed.get_string().data()];
        case RLMPropertyTypeInt: {
            return @(mixed.get_int());
        case RLMPropertyTypeFloat:
            return @(mixed.get_float());
        case RLMPropertyTypeDouble:
            return @(mixed.get_double());
        case RLMPropertyTypeBool:
            return @(mixed.get_bool());
        case RLMPropertyTypeDate:
            return [NSDate dateWithTimeIntervalSince1970:mixed.get_datetime().get_datetime()];
        case RLMPropertyTypeData: {
            tightdb::BinaryData bd = mixed.get_binary();
            NSData *d = [NSData dataWithBytes:bd.data() length:bd.size()];
            return d;
        }
        default:
            @throw [NSException exceptionWithName:@"RLMException" reason:@"Invalid data type for RLMPropertyTypeAny property." userInfo:nil];
        }
    }
}





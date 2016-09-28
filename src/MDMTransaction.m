/*
 Copyright 2016-present The Material Motion Authors. All Rights Reserved.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "MDMTransaction.h"
#import "MDMTransaction+Private.h"
#import "MDMPerforming.h"
#import "MDMPlan.h"

@implementation MDMTransaction {
  NSMutableArray *_logs;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _logs = [NSMutableArray array];
  }
  return self;
}

- (void)addPlan:(NSObject<MDMPlan> *)plan toTarget:(id)target {
  [self commonAddPlan:plan toTarget:target withName:nil];
}

- (void)addPlan:(NSObject<MDMPlan> *)plan toTarget:(id)target withName:(NSString *)name {
  [self removePlanNamed:name fromTarget:target];
  [self commonAddPlan:plan toTarget:target withName:name];
}

- (void)commonAddPlan:(NSObject<MDMPlan> *)plan toTarget:(id)target withName:(NSString *)name {
  MDMTransactionLogType transactionLogType = name == nil ? MDMTransactionLogTypeUncategorized : MDMTransactionLogTypeAddNamedPlan;
  MDMTransactionLog *log = [[MDMTransactionLog alloc] initWithPlan:[plan copy] target:target name:name transactionLogType:transactionLogType];
  [_logs addObject:log];
}

- (void)removePlanNamed:(nonnull NSString *)name fromTarget:(nonnull id)target {
  MDMTransactionLog *log = [[MDMTransactionLog alloc] initWithPlan:nil target:target name:name transactionLogType:MDMTransactionLogTypeRemoveNamedPlan];
  [_logs removeObject:log];
}

- (NSArray<MDMTransactionLog *> *)logs {
  return _logs;
}

@end

@implementation MDMTransactionLog

- (instancetype)initWithPlan:(NSObject<MDMPlan> *)plan target:(id)target name:(NSString *)name transactionLogType:(MDMTransactionLogType)transactionLogType {
  self = [super init];
  if (self) {
    if (plan != nil) {
      _plans = @[ plan ];
    }
    _target = target;
    _name = [name copy];
    _transactionLogType = transactionLogType;
  }
  return self;
}

- (BOOL)isEqual:(id)other {
  if (other == self) {
    return YES;
  } else {
    MDMTransactionLog *otherTransaction = (MDMTransactionLog *)other;
    if ([self.target isEqual:otherTransaction.target]) {
      if (self.name != nil) {
        return [self.name isEqualToString:otherTransaction.name];
      } else {
        return otherTransaction.name == nil;
      }
    } else {
      return NO;
    }
  }
}

- (NSUInteger)hash {
  return [self.target hash] ^ [self.name hash] ^ self.transactionLogType;
}

@end

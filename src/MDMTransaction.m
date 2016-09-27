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
  NSMutableSet *_namedPlans;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _logs = [NSMutableArray array];
    _namedPlans = [NSMutableSet set];
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
  MDMTransactionLog *log = [self newLogWithPlan:plan target:target name:name];
  if (name.length) {
    Class performerClass = [plan performerClass];
    id performer = [[performerClass alloc] initWithTarget:target];
    if ([performer conformsToProtocol:@protocol(MDMNamedPlanPerforming)] &&
        [performer respondsToSelector:@selector(addPlan:withName:)]) {
      [performer addPlan:plan withName:name];
    }
    [_namedPlans addObject:log];
  }
  [_logs addObject:log];
}

- (void)removePlanNamed:(nonnull NSString *)name fromTarget:(nonnull id)target {
  MDMTransactionLog *log = [self newLogWithPlan:nil target:target name:name];
  if ([_namedPlans containsObject:log]) {
    if ([target isEqual:log.target]) {
      for (id<MDMPlan>plan in [log plans]) {
        Class performerClass = [plan performerClass];
        id performer = [[performerClass alloc] initWithTarget:[log target]];
        if ([performer conformsToProtocol:@protocol(MDMNamedPlanPerforming)] &&
            [performer respondsToSelector:@selector(removePlan:withName:)]) {
          [performer removePlan:plan withName:name];
        }
      }
    }
    [_namedPlans removeObject:log];
    [_logs removeObject:log];
  }
}

- (NSArray<MDMTransactionLog *> *)logs {
  return _logs;
}

- (MDMTransactionLog *)newLogWithPlan:(NSObject<MDMPlan> *)plan target:(id)target name:(NSString *)name {
  // consider a initWithPlan:target:name initializer on `MDMTransactionLog`?
  MDMTransactionLog *log = [MDMTransactionLog new];
  if (plan != nil) {
    log.plans = @[ plan ];
  }
  log.target = target;
  log.name = name;
  return log;
}

@end

@implementation MDMTransactionLog

- (BOOL)isEqual:(id)other {
  if (other == self) {
    return YES;
  } else {
    if ([other isKindOfClass:[MDMTransactionLog class]]) {
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
    } else {
      return NO;
    }
  }
}

- (NSUInteger)hash {
  return [self.target hash] ^ [self.name hash];
}

@end

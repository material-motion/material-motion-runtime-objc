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
  NSMutableDictionary *_namedPlans;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _logs = [NSMutableArray array];
    _namedPlans = [NSMutableDictionary dictionary];
  }
  return self;
}

- (void)addPlan:(NSObject<MDMPlan> *)plan toTarget:(id)target {
  [self commonAddPlan:plan toTarget:target withName:nil];
}

- (void)addPlan:(NSObject<MDMPlan> *)plan toTarget:(id)target withName:(NSString *)name {
  [self commonAddPlan:plan toTarget:target withName:name];
}

- (void)commonAddPlan:(NSObject<MDMPlan> *)plan toTarget:(id)target withName:(NSString *)name {
  NSObject<MDMPlan> *copiedPlan = [plan copy];
  MDMTransactionLog *log = [MDMTransactionLog new];
  log.plans = @[ copiedPlan ];
  log.target = target;
  log.name = name;
  if (name.length) {
    _namedPlans[name] = log;
  }
  [_logs addObject:log];
}

- (void)removePlanNamed:(nonnull NSString *)name {
  MDMTransactionLog *planLog = _namedPlans[name];
  if (planLog != nil && _namedPlans[name] != nil) {
    for (id<MDMPlan>plan in [planLog plans]) {
      // unsure of how to get access to the original performer instance when all I get from MDMPlan is `performerClass`
      // MDMPerformerInfo instances are housed in MDMPerformerGroup and I believe that's where the performer instance is housed. I guess we could open up access to these instances in MDMPerformerGroup ?
      // creating a new performer here, but unsure if that's the correct way of handling this
      Class performerClass = [plan performerClass];
      id<MDMPlanPerforming> performer = [[performerClass alloc] initWithTarget:[planLog target]];
      if ([performer respondsToSelector:@selector(removePlan:)]) {
        [performer removePlan:plan];
      }
    }
    [_namedPlans removeObjectForKey:name];
    [_logs removeObject:planLog];
  }
}

- (NSArray<MDMTransactionLog *> *)logs {
  return _logs;
}

@end

@implementation MDMTransactionLog
@end

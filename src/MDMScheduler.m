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

#import "MDMScheduler.h"

#import "MDMPerformerGroup.h"
#import "MDMPerformerGroupDelegate.h"
#import "MDMTrace.h"
#import "MDMTraceNotification.h"
#import "MDMTracing.h"
#import "MDMTransaction+Private.h"

@interface MDMScheduler () <MDMPerformerGroupDelegate>

@property(nonatomic, strong) NSMapTable *targetToPerformerGroup;
@property(nonatomic, strong) NSMutableSet *activePerformerGroups;

@end

@implementation MDMScheduler {
  NSMutableOrderedSet *_tracers;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _tracers = [NSMutableOrderedSet orderedSet];
    _targetToPerformerGroup = [NSMapTable weakToStrongObjectsMapTable];
    _activePerformerGroups = [NSMutableSet set];
  }
  return self;
}

#pragma mark - Private

- (MDMPerformerGroup *)performerGroupForTarget:(id)target {
  MDMPerformerGroup *performerGroup = [_targetToPerformerGroup objectForKey:target];
  if (!performerGroup) {
    performerGroup = [[MDMPerformerGroup alloc] initWithTarget:target scheduler:self];
    performerGroup.delegate = self;
    [self.targetToPerformerGroup setObject:performerGroup forKey:target];
  }

  return performerGroup;
}

#pragma mark MDMPerformerGroupDelegate

- (void)performerGroup:(MDMPerformerGroup *)performerGroup activeStateDidChange:(BOOL)isActive {
  BOOL schedulerWasActive = [self activityState] == MDMSchedulerActivityStateActive;

  if (isActive) {
    [self.activePerformerGroups addObject:performerGroup];
  } else {
    [self.activePerformerGroups removeObject:performerGroup];
  }

  BOOL schedulerIsActive = [self activityState] == MDMSchedulerActivityStateActive;
  if (schedulerWasActive != schedulerIsActive) {
    [self.delegate schedulerActivityStateDidChange:self];
  }
}

#pragma mark - Public

- (MDMSchedulerActivityState)activityState {
  return (self.activePerformerGroups.count > 0) ? MDMSchedulerActivityStateActive : MDMSchedulerActivityStateIdle;
}

- (void)addPlan:(NSObject<MDMPlan> *)plan toTarget:(id)target {
  [self commonAddPlan:plan toTarget:target log:nil];
}

- (void)addPlan:(NSObject<MDMPlan> *)plan named:(NSString *)name toTarget:(id)target {
  NSParameterAssert(name.length > 0);
  [self commonAddPlan:plan toTarget:target log:[[MDMTransactionLog alloc] initWithPlans:@[plan] target:target name:name removal:FALSE]];
}

- (void)removePlanNamed:(NSString *)name fromTarget:(id)target {
  NSParameterAssert(name.length > 0);
  [self commonAddPlan:nil toTarget:target log:[[MDMTransactionLog alloc] initWithTarget:target name:name]];
}

#pragma mark - Private

- (void)commonAddPlan:(NSObject<MDMPlan> *)plan toTarget:(id)target log:(MDMTransactionLog *)log {
  MDMTrace *trace = [MDMTrace new];
  
  NSObject<MDMPlan> *copiedPlan = [plan copy];
  [[self performerGroupForTarget:target] addPlan:[plan copy] trace:trace log:log];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  if ([trace.committedAddPlans count] || [trace.committedRemovePlans count]) {
    MDMSchedulerPlansCommittedTracePayload *payload = [MDMSchedulerPlansCommittedTracePayload new];
    payload.committedAddPlans = [trace.committedAddPlans copy];
    payload.committedRemovePlans = [trace.committedRemovePlans copy];

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:MDMTraceNotificationNamePlansCommitted
                      object:self
                    userInfo:@{MDMTraceNotificationPayloadKey : payload}];
  }
  if ([trace.createdPerformers count]) {
    MDMSchedulerPerformersCreatedTracePayload *event = [MDMSchedulerPerformersCreatedTracePayload new];
    event.createdPerformers = [trace.createdPerformers copy];

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:MDMTraceNotificationNamePerformersCreated
                      object:self
                    userInfo:@{MDMTraceNotificationPayloadKey : event}];
  }
#pragma clang diagnostic pop

  for (id<MDMTracing> tracer in _tracers) {
    if ([tracer respondsToSelector:@selector(didAddPlan:to:)]) {
      [tracer didAddPlan:copiedPlan to:target];
    }
  }
}

- (void)addTracer:(nonnull id<MDMTracing>)tracer {
  [_tracers addObject:tracer];
}

- (void)removeTracer:(nonnull id<MDMTracing>)tracer {
  [_tracers removeObject:tracer];
}

- (nonnull NSArray<id<MDMTracing>> *)tracers {
  return _tracers.array;
}

#pragma mark - Deprecated

- (void)commitTransaction:(MDMTransaction *)transaction {
  MDMTrace *trace = [MDMTrace new];

  for (MDMTransactionLog *log in [transaction logs]) {
    [[self performerGroupForTarget:log.target] executeLog:log trace:trace];
  }

  if ([trace.committedAddPlans count] || [trace.committedRemovePlans count]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    MDMSchedulerPlansCommittedTracePayload *payload = [MDMSchedulerPlansCommittedTracePayload new];
    payload.committedAddPlans = [trace.committedAddPlans copy];
    payload.committedRemovePlans = [trace.committedRemovePlans copy];

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:MDMTraceNotificationNamePlansCommitted
                      object:self
                    userInfo:@{MDMTraceNotificationPayloadKey : payload}];
  }
  if ([trace.createdPerformers count]) {
    MDMSchedulerPerformersCreatedTracePayload *event = [MDMSchedulerPerformersCreatedTracePayload new];
    event.createdPerformers = [trace.createdPerformers copy];

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:MDMTraceNotificationNamePerformersCreated
                      object:self
                    userInfo:@{MDMTraceNotificationPayloadKey : event}];
  }
#pragma clang diagnostic pop
}

@end

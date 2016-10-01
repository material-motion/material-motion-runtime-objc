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
#import "MDMTransaction+Private.h"

@interface MDMScheduler () <MDMPerformerGroupDelegate>

@property(nonatomic, strong) NSMapTable *targetToPerformerGroup;

@property(nonatomic, strong) NSMutableSet *activePerformerGroups;

@end

@implementation MDMScheduler

- (instancetype)init {
  self = [super init];
  if (self) {
    NSPointerFunctionsOptions keyOptions = (NSPointerFunctionsObjectPointerPersonality | NSPointerFunctionsWeakMemory);
    NSPointerFunctionsOptions valueOptions = (NSPointerFunctionsObjectPointerPersonality | NSPointerFunctionsStrongMemory);
    _targetToPerformerGroup = [NSMapTable mapTableWithKeyOptions:keyOptions valueOptions:valueOptions];

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

    // TODO: Add event hook for plugins. This is where a plugin might provide a scheduler target. This
    // is how view duplicaion gets hooked in to the scheduler.
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
  MDMTrace *trace = [MDMTrace new];
  [[self performerGroupForTarget:target] addPlan:[plan copy] trace:trace];
  if ([trace.committedPlans count]) {
    MDMSchedulerPlansCommittedTracePayload *payload = [MDMSchedulerPlansCommittedTracePayload new];
    payload.committedPlans = [trace.committedPlans copy];

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
}

#pragma mark - Deprecated

- (void)commitTransaction:(MDMTransaction *)transaction {
  MDMTrace *trace = [MDMTrace new];

  for (MDMTransactionLog *log in [transaction logs]) {
    [[self performerGroupForTarget:log.target] executeLog:log trace:trace];
  }

  if ([trace.committedPlans count]) {
    MDMSchedulerPlansCommittedTracePayload *payload = [MDMSchedulerPlansCommittedTracePayload new];
    payload.committedPlans = [trace.committedPlans copy];

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
}

@end

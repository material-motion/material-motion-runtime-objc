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

#import "MDMPerformerGroup.h"

#import "MDMIsActiveTokenGenerator.h"
#import "MDMPerformerGroupDelegate.h"
#import "MDMPerformerInfo.h"
#import "MDMPerforming.h"
#import "MDMPlan.h"
#import "MDMPlanEmitter.h"
#import "MDMScheduler.h"
#import "MDMTrace.h"
#import "MDMTracing.h"
#import "MDMTransaction+Private.h"
#import "MDMTransactionEmitter.h"

@interface MDMPerformerGroup ()
@property(nonatomic, weak) MDMScheduler *scheduler;
@property(nonatomic, strong, readonly) NSMutableArray<MDMPerformerInfo *> *performerInfos;
@property(nonatomic, strong, readonly) NSMutableDictionary *performerClassNameToPerformerInfo;
@property(nonatomic, strong, readonly) NSMutableDictionary *performerPlanNameToPerformerInfo;
@property(nonatomic, strong, readonly) NSMutableSet *activePerformers;
@end

@implementation MDMPerformerGroup

- (instancetype)initWithTarget:(id)target scheduler:(MDMScheduler *)scheduler {
  self = [super init];
  if (self) {
    _target = target;
    _scheduler = scheduler;
    _performerInfos = [NSMutableArray array];
    _performerClassNameToPerformerInfo = [NSMutableDictionary dictionary];
    _performerPlanNameToPerformerInfo = [NSMutableDictionary dictionary];
    _activePerformers = [NSMutableSet set];
  }
  return self;
}

- (void)addPlan:(nonnull id<MDMPlan>)plan to:(nonnull id)target trace:(MDMTrace *)trace {
  id<MDMPerforming> performer = [self findOrCreatePerformerForPlan:plan trace:trace];
  [self notifyPlanAdded:plan to:target trace:trace];
  if ([performer respondsToSelector:@selector(addPlan:)]) {
    [(id<MDMPlanPerforming>)performer addPlan:plan];
  }
}

- (void)addPlan:(nonnull id<MDMNamedPlan>)plan named:(nonnull NSString *)name to:(nonnull id)target trace:(MDMTrace *)trace {
  // remove first
  [self removePlanNamed:name from:target withPerformerInfo:[self findOrCreatePerformerInfoForPlan:plan trace:trace]];
  [trace.committedRemovePlans addObject:plan];
  // then add
  id<MDMPerforming> performer = [self findOrCreatePerformerForNamedPlan:plan named:name trace:trace];
  [self notifyPlanAdded:plan to:target trace:trace];
  if ([performer respondsToSelector:@selector(addPlan:named:)]) {
    [(id<MDMNamedPlanPerforming>)performer addPlan:plan named:name];
  }
}

- (void)removePlanNamed:(nonnull NSString *)name from:(nonnull id)target {
  [self removePlanNamed:name from:target withPerformerInfo:self.performerPlanNameToPerformerInfo[name]];
}

- (void)registerIsActiveToken:(id<MDMIsActiveTokenable>)token
            withPerformerInfo:(MDMPerformerInfo *)performerInfo {
  NSAssert(performerInfo.performer, @"Performer no longer exists.");

  [performerInfo.isActiveTokens addObject:token];

  [self didRegisterTokenForPerformerInfo:performerInfo];
}

- (void)terminateIsActiveToken:(id<MDMIsActiveTokenable>)token
             withPerformerInfo:(MDMPerformerInfo *)performerInfo {
  NSAssert(performerInfo.performer, @"Performer no longer exists.");
  NSAssert([performerInfo.isActiveTokens containsObject:token],
           @"Token is not active. May have already been terminated by a previous invocation.");

  [performerInfo.isActiveTokens removeObject:token];

  [self didTerminateTokenForPerformerInfo:performerInfo];
}

#pragma mark - Private

- (void)removePlanNamed:(nonnull NSString *)name from:(nonnull id)target withPerformerInfo:(nullable MDMPerformerInfo *)performerInfo {
  if (performerInfo) {
    id<MDMPerforming> performer = performerInfo.performer;
    if ([performer respondsToSelector:@selector(removePlanNamed:)]) {
      [(id<MDMNamedPlanPerforming>)performer removePlanNamed:name];
    }
  } else {
    // this is the case whereby the client has tried to remove a named performer which was never added in the first place
  }
}

- (id<MDMPerforming>)findOrCreatePerformerForPlan:(id<MDMPlan>)plan trace:(MDMTrace *)trace {
  return [self findOrCreatePerformerInfoForPlan:plan trace:trace].performer;
}

- (id<MDMPerforming>)findOrCreatePerformerForNamedPlan:(id<MDMNamedPlan>)plan named:(NSString *)name trace:(MDMTrace *)trace {
  // maybe this is a simple lookup
  MDMPerformerInfo *performerInfo = self.performerPlanNameToPerformerInfo[name];
  if (performerInfo.performer) {
    return performerInfo.performer;
  }
  // see if we can look it up by class name instead
  performerInfo = [self findOrCreatePerformerInfoForPlan:plan trace:trace];
  // stash this perfomer info in case we ever want to look it up again
  self.performerPlanNameToPerformerInfo[name] = performerInfo;
  return performerInfo.performer;
}

- (MDMPerformerInfo *)findOrCreatePerformerInfoForPlan:(id<MDMPlan>)plan trace:(MDMTrace *)trace {
  Class performerClass = [plan performerClass];
  id performerClassName = NSStringFromClass(performerClass);
  MDMPerformerInfo *performerInfo = self.performerClassNameToPerformerInfo[performerClassName];
  if (performerInfo) {
    return performerInfo;
  } else {
    id<MDMPerforming> performer = [[performerClass alloc] initWithTarget:self.target];
    performerInfo = [[MDMPerformerInfo alloc] init];
    performerInfo.performer = performer;
    [self.performerInfos addObject:performerInfo];
    if (performerClassName != nil) {
      self.performerClassNameToPerformerInfo[performerClassName] = performerInfo;
    }
    [self setUpFeaturesForPerformerInfo:performerInfo];
    // tell everyone else that you just created a performer
    [trace.createdPerformers addObject:performer];
    for (id<MDMTracing> tracer in self.scheduler.tracers) {
      if ([tracer respondsToSelector:@selector(didCreatePerformer:for:)]) {
        [tracer didCreatePerformer:performer for:self.target];
      }
    }
    return performerInfo;
  }
}

- (void)setUpFeaturesForPerformerInfo:(MDMPerformerInfo *)performerInfo {
  id<MDMPerforming> performer = performerInfo.performer;

  // Composable performance
  if ([performer respondsToSelector:@selector(setPlanEmitter:)]) {
    id<MDMComposablePerforming> composablePerformer = (id<MDMComposablePerforming>)performer;

    MDMPlanEmitter *emitter = [[MDMPlanEmitter alloc] initWithScheduler:self.scheduler target:self.target];
    [composablePerformer setPlanEmitter:emitter];
  }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  if ([performer respondsToSelector:@selector(setTransactionEmitter:)]) {
    id<MDMComposablePerforming> composablePerformer = (id<MDMComposablePerforming>)performer;

    MDMTransactionEmitter *emitter = [[MDMTransactionEmitter alloc] initWithScheduler:self.scheduler];
    [composablePerformer setTransactionEmitter:emitter];
  }
#pragma clang diagnostic pop

  // Is-active performance

  if ([performer respondsToSelector:@selector(setIsActiveTokenGenerator:)]) {
    id<MDMContinuousPerforming> continuousPerformer = (id<MDMContinuousPerforming>)performer;

    MDMIsActiveTokenGenerator *generator = [[MDMIsActiveTokenGenerator alloc] initWithPerformerGroup:self
                                                                                       performerInfo:performerInfo];
    [continuousPerformer setIsActiveTokenGenerator:generator];
  }
}

- (void)didRegisterTokenForPerformerInfo:(MDMPerformerInfo *)performerInfo {
  BOOL wasInactive = self.activePerformers.count == 0;

  [self.activePerformers addObject:performerInfo.performer];

  if (wasInactive) {
    [self.delegate performerGroup:self activeStateDidChange:YES];
  }
}

- (void)didTerminateTokenForPerformerInfo:(MDMPerformerInfo *)performerInfo {
  if (performerInfo.isActiveTokens.count == 0 && performerInfo.delegatedPerformanceTokens.count == 0) {
    [self.activePerformers removeObject:performerInfo.performer];

    if (self.activePerformers.count == 0) {
      [self.delegate performerGroup:self activeStateDidChange:NO];
    }
  }
}

- (void)notifyPlanAdded:(id<MDMPlan>)plan to:(id)target trace:(MDMTrace *)trace {
  [trace.committedAddPlans addObject:plan];
  for (id<MDMTracing> tracer in self.scheduler.tracers) {
    if ([tracer respondsToSelector:@selector(didAddPlan:to:)]) {
      [tracer didAddPlan:plan to:target];
    }
  }
}

#pragma mark - Deprecated

- (void)executeLog:(MDMTransactionLog *)log trace:(MDMTrace *)trace {
  for (id<MDMPlan> plan in log.plans) {
    if (log.isRemoval) {
      [self removePlanNamed:log.name from:log.target];
    } else if (log.name.length) {
      [self addPlan:(id<MDMNamedPlan>)plan named:log.name to:log.target trace:trace];
    } else {
      [self addPlan:plan to:log.target trace:trace];
    }
  }
}

@end

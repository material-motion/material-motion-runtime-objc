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

- (void)addPlan:(id<MDMPlan>)plan trace:(MDMTrace *)trace {
  [self addPlan:plan trace:trace log:nil];
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

- (void)addPlan:(id<MDMPlan>)plan trace:(MDMTrace *)trace log:(MDMTransactionLog *)log {
  // all named addPlan plans must first be removed before being added
  if ([self isNamedTransactionLog:log] && !log.isRemoval) {
    [self addPlan:plan trace:trace log:[[MDMTransactionLog alloc] initWithPlans:@[plan] target:log.target name:log.name removal:TRUE]];
  }
  // see if we can get a performer
  id<MDMPerforming> performer = [self performerForPlan:plan trace:trace log:log];
  if (performer != nil) {
    if (plan != nil) {
      if (log.isRemoval) {
        [trace.committedRemovePlans addObject:plan];
      } else {
        [trace.committedAddPlans addObject:plan];
      }
    } else {
      // this is the case whereby we are calling removePlan:named, but don't have a MDMPlan
    }

    if ([self isNamedTransactionLog:log]) {
      id<MDMNamedPlan> namedPlan = (id<MDMNamedPlan>)plan;
      if (log.isRemoval) {
        if ([performer respondsToSelector:@selector(removePlanNamed:)]) {
          [(id<MDMNamedPlanPerforming>)performer removePlanNamed:log.name];
        }
      } else if ([performer respondsToSelector:@selector(addPlan:named:)]) {
        [(id<MDMNamedPlanPerforming>)performer addPlan:namedPlan named:log.name];
      }
    } else {
      if ([performer respondsToSelector:@selector(addPlan:)]) {
        [(id<MDMPlanPerforming>)performer addPlan:plan];
      }
    }
  } else {
    // this is the case whereby the client has tried to remove a named performer which was never added in the first place
  }
}

- (id<MDMPerforming>)performerForPlan:(id<MDMPlan>)plan trace:(MDMTrace *)trace log:(MDMTransactionLog *)log {
  BOOL isNew = NO;
  id<MDMPerforming> performer = [self performerForPlan:plan log:log isNew:&isNew];
  if (performer && isNew) {
    [trace.createdPerformers addObject:performer];
    for (id<MDMTracing> tracer in self.scheduler.tracers) {
      if ([tracer respondsToSelector:@selector(didCreatePerformer:for:)]) {
        [tracer didCreatePerformer:performer for:self.target];
      }
    }
  }
  return performer;
}

- (id<MDMPerforming>)performerForPlan:(id<MDMPlan>)plan log:(MDMTransactionLog *)log isNew:(BOOL *)isNew {
  if ([self isNamedTransactionLog:log]) {
    // first see if we can find the performer based on the name
    MDMPerformerInfo *performerInfo = self.performerPlanNameToPerformerInfo[log.name];
    if (performerInfo) {
      *isNew = NO;
      return performerInfo.performer;
    } else {
      // otherwise, see if we can find the performer based on the class associated with the plan
      return [self findPerformerForPlan:plan log:log isNew:isNew];
    }
  } else {
    return [self findPerformerForPlan:plan log:log isNew:isNew];
  }
}

- (id<MDMPerforming>)findPerformerForPlan:(id<MDMPlan>)plan log:(MDMTransactionLog *)log isNew:(BOOL *)isNew {
  Class performerClass = [plan performerClass];
  id performerClassName = NSStringFromClass(performerClass);
  MDMPerformerInfo *performerInfo = self.performerClassNameToPerformerInfo[performerClassName];
  if (performerInfo) {
    *isNew = NO;
    return performerInfo.performer;
  }

  id<MDMPerforming> performer = [[performerClass alloc] initWithTarget:self.target];

  performerInfo = [[MDMPerformerInfo alloc] init];
  performerInfo.performer = performer;

  [self.performerInfos addObject:performerInfo];
  if (performerClassName != nil) {
    self.performerClassNameToPerformerInfo[performerClassName] = performerInfo;
  }
  if ([self isNamedTransactionLog:log]) {
    self.performerPlanNameToPerformerInfo[log.name] = performerInfo;
  }

  [self setUpFeaturesForPerformerInfo:performerInfo];

  *isNew = YES;

  return performer;
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

- (BOOL)isNamedTransactionLog:(MDMTransactionLog *)log {
  return log != nil && log.name.length > 0;
}

#pragma mark - Deprecated

- (void)executeLog:(MDMTransactionLog *)log trace:(MDMTrace *)trace {
  for (id<MDMPlan> plan in log.plans) {
    [self addPlan:plan trace:trace log:log];
    for (id<MDMTracing> tracer in self.scheduler.tracers) {
      if ([tracer respondsToSelector:@selector(didAddPlan:to:)]) {
        [tracer didAddPlan:plan to:log.target];
      }
    }
  }
}

@end

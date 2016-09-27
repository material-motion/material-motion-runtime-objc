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
#import "MDMScheduler.h"
#import "MDMTrace.h"
#import "MDMTransaction+Private.h"
#import "MDMTransactionEmitter.h"

// TODO: Remove upon deletion of deprecation delegation APIs.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
@interface MDMDelegatedPerformanceToken : NSObject <MDMDelegatedPerformingToken>
@end
#pragma clang diagnostic pop

@implementation MDMDelegatedPerformanceToken
@end

@interface MDMPerformerGroup ()
@property(nonatomic, weak) MDMScheduler *scheduler;
@property(nonatomic, strong, readonly) NSMutableArray<MDMPerformerInfo *> *performerInfos;
@property(nonatomic, strong, readonly) NSMutableDictionary *performerClassNameToPerformerInfo;
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
    _activePerformers = [NSMutableSet set];
  }
  return self;
}

- (void)executeLog:(MDMTransactionLog *)log trace:(MDMTrace *)trace {
  [trace.committedPlans addObjectsFromArray:log.plans];

  for (id<MDMPlan> plan in log.plans) {
    BOOL isNew = NO;
    id<MDMPerforming> performer = [self performerForPlan:plan isNew:&isNew];

    if (isNew) {
      [trace.createdPerformers addObject:performer];
    }

    if ([performer respondsToSelector:@selector(addPlan:)]) {
      [(id<MDMPlanPerforming>)performer addPlan:plan];
    }
    
    // MDMNamedPlanPerforming callbacks
    switch (log.transactionLogType) {
      case MDMTransactionLogTypeAddNamedPlan: {
        if ([performer respondsToSelector:@selector(addPlan:withName:)]) {
          [(id<MDMNamedPlanPerforming>)performer addPlan:plan withName:log.name];
        }
      } break;
      case MDMTransactionLogTypeRemoveNamedPlan: {
        if ([performer respondsToSelector:@selector(removePlanNamed:)]) {
          [(id<MDMNamedPlanPerforming>)performer removePlanNamed:log.name];
        }
      } break;
      default:
        break;
    }
  }
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

- (id<MDMPerforming>)performerForPlan:(id<MDMPlan>)plan isNew:(BOOL *)isNew {
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
  self.performerClassNameToPerformerInfo[performerClassName] = performerInfo;

  [self setUpFeaturesForPerformerInfo:performerInfo];

  *isNew = YES;

  return performer;
}

- (void)setUpFeaturesForPerformerInfo:(MDMPerformerInfo *)performerInfo {
  id<MDMPerforming> performer = performerInfo.performer;

  // Composable performance

  if ([performer respondsToSelector:@selector(setTransactionEmitter:)]) {
    id<MDMComposablePerforming> composablePerformer = (id<MDMComposablePerforming>)performer;

    MDMTransactionEmitter *emitter = [[MDMTransactionEmitter alloc] initWithScheduler:self.scheduler];
    [composablePerformer setTransactionEmitter:emitter];
  }

  // Is-active performance

  if ([performer respondsToSelector:@selector(setIsActiveTokenGenerator:)]) {
    id<MDMContinuousPerforming> continuousPerformer = (id<MDMContinuousPerforming>)performer;

    MDMIsActiveTokenGenerator *generator = [[MDMIsActiveTokenGenerator alloc] initWithPerformerGroup:self
                                                                                       performerInfo:performerInfo];
    [continuousPerformer setIsActiveTokenGenerator:generator];
  }

  // Delegated performance
  // TODO: Remove upon deletion of deprecation delegation APIs.

  if ([performer respondsToSelector:@selector(setDelegatedPerformanceWillStart:didEnd:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    id<MDMDelegatedPerforming> delegatedPerformer = (id<MDMDelegatedPerforming>)performer;

    __weak MDMPerformerInfo *weakInfo = performerInfo;
    __weak MDMPerformerGroup *weakSelf = self;
    MDMDelegatedPerformanceTokenReturnBlock willStartBlock = ^(void) {
      MDMPerformerInfo *strongInfo = weakInfo;
      MDMPerformerGroup *strongSelf = weakSelf;
      if (!strongInfo || !strongSelf || !strongSelf->_scheduler) {
        return (id<MDMDelegatedPerformingToken>)nil;
      }

      // Register the work

      MDMDelegatedPerformanceToken *token = [MDMDelegatedPerformanceToken new];
      [strongInfo.delegatedPerformanceTokens addObject:token];

      // Check our group's activity state

      // TODO(featherless): If/when we explore multi-threaded schedulers we need to more cleanly
      // propagate activity state up to the Scheduler. As it stands, this code is not thread-safe.

      [self didRegisterTokenForPerformerInfo:performerInfo];

      return (id<MDMDelegatedPerformingToken>)token;
    };

    MDMDelegatedPerformanceTokenArgBlock didEndBlock = ^(id<MDMDelegatedPerformingToken> token) {
      MDMPerformerInfo *strongInfo = weakInfo;
      MDMPerformerGroup *strongSelf = weakSelf;
      if (!strongInfo || !strongSelf || !strongSelf->_scheduler) {
        return;
      }

      NSAssert([strongInfo.delegatedPerformanceTokens containsObject:token],
               @"Token is not active. May have already been terminated by a previous invocation.");
      [strongInfo.delegatedPerformanceTokens removeObject:token];

      [strongSelf didTerminateTokenForPerformerInfo:strongInfo];
    };

    [delegatedPerformer setDelegatedPerformanceWillStart:willStartBlock didEnd:didEndBlock];
#pragma clang diagnostic pop
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

@end

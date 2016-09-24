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

#import <Foundation/Foundation.h>

/**
 A class conforming to MDMPerforming is expected to implement the plan of motion described by objects
 that conform to MDMPlan.
 */
NS_SWIFT_NAME(Performing)
@protocol MDMPerforming <NSObject>

#pragma mark Designated initializer

/** The receiver is expected to execute its plan to the provided target. */
- (nonnull instancetype)initWithTarget:(nonnull id)target;

@end

@class MDMTransaction;
@protocol MDMPlan;

/** A class conforming to this protocol will be provided with plan instances. */

NS_SWIFT_NAME(PlanPerforming)
@protocol MDMPlanPerforming <MDMPerforming>

#pragma mark Adding plans to a performer

/**
 Provides the performer with an plan.

 The performer may choose to store this plan or to simply extract necessary information and cache
 it separately.

 @param plan The plan that required this type of performer.
 */
- (void)addPlan:(nonnull id<MDMPlan>)plan
    NS_SWIFT_NAME(add(plan:));

@optional

- (void)removePlan:(nonnull id<MDMPlan>)plan
    NS_SWIFT_NAME(remove(plan:));

@end

#pragma mark - Delegated performing

/**
 An object conforming to MDMDelegatedPerformingToken represents a single unit of delegated
 performance.
 */
NS_SWIFT_NAME(DelegatedPerformingToken)
@protocol MDMDelegatedPerformingToken <NSObject>
@end

/** A block that returns a delegated performance token. */
NS_SWIFT_NAME(DelegatedPerformanceTokenReturnBlock)
typedef _Nullable id<MDMDelegatedPerformingToken> (^MDMDelegatedPerformanceTokenReturnBlock)(void);

/** A block that accepts a delegated performance token. */
NS_SWIFT_NAME(DelegatedPerformanceTokenArgBlock)
typedef void (^MDMDelegatedPerformanceTokenArgBlock)(_Nonnull id<MDMDelegatedPerformingToken>);

/**
 A class conforming to MDMDelegatedPerforming is expected to delegate execution to an external system.
 */
NS_SWIFT_NAME(DelegatedPerforming)
@protocol MDMDelegatedPerforming <MDMPerforming>

@optional

#pragma mark Delegating performing

/**
 The performer will be provided with two methods for indicating the current activity state of the
 performer.
 */
- (void)setDelegatedPerformanceWillStart:(nonnull MDMDelegatedPerformanceTokenReturnBlock)willStart
                                  didEnd:(nonnull MDMDelegatedPerformanceTokenArgBlock)didEnd
    NS_SWIFT_NAME(setDelegatedPerformance(willStart:didEnd:));

@end

/** A transaction emitter allows a performer to commit new plans to a scheduler. */
NS_SWIFT_NAME(TransactionEmitting)
@protocol MDMTransactionEmitting <NSObject>

/** Emit a new transaction. The transaction will immediately be committed to the scheduler. */
- (void)emitTransaction:(nonnull MDMTransaction*)transaction
    NS_SWIFT_NAME(emit(transaction:));

@end

/** A class conforming to MDMComposablePerforming is able to commit new plans. */
NS_SWIFT_NAME(ComposablePerforming)
@protocol MDMComposablePerforming <MDMPerforming>

@optional

#pragma mark Composable performing

/** The performer will be provided with a method for initiating a new transaction. */
- (void)setTransactionEmitter:(nonnull id<MDMTransactionEmitting>)transactionEmitter
    NS_SWIFT_NAME(set(transactionEmitter:));

@end
